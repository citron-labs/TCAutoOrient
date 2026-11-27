using System;
using System.IO;
using System.Linq;
using Autodesk.Revit.DB;
namespace TCAutoOrient {
 public static class FamilySetup {
  public const string FamilyName="TC - Base Wall Drop1";
  public const string BundledFamilyName="TC - Base Wall Drop AutoOrient";
  public const string BundledFamilyFile=BundledFamilyName+".rfa";
  public const string Auto="TC Auto Orient";
  public const string Quadrant="TC Label Quadrant";
  public const string Schema="TC Auto Orient Version";
  public const string AnnotationName="TC_WALL DROP SYMBOL";
  public const int CurrentSchema=2;
  public static bool Matches(Family f) { return f!=null && (f.Name.Equals(FamilyName,StringComparison.OrdinalIgnoreCase)||f.Name.Equals(BundledFamilyName,StringComparison.OrdinalIgnoreCase)); }
  public static bool Prepared(FamilyInstance f) { return Matches(f.Symbol.Family)&&f.LookupParameter(Quadrant)!=null; }
  static FamilyParameter Param(FamilyManager fm,string name) { return fm.Parameters.Cast<FamilyParameter>().SingleOrDefault(p=>p.Definition.Name==name); }
  static FamilyParameter Ensure(FamilyManager fm,string name,ForgeTypeId type,bool instance) { return Param(fm,name)??fm.AddParameter(name,GroupTypeId.Graphics,type,instance); }
  static void SetNumberVisibility(FamilyManager fm) {
   for(int q=0;q<4;q++)fm.SetFormula(Param(fm,Orientation.NumberFlag(q)),"and("+Quadrant+" = "+q+", not(# of Ports = 0))");
  }
  public static void LoadBundledFamily(Document project) {
   var path=Path.Combine(Path.GetDirectoryName(typeof(FamilySetup).Assembly.Location),BundledFamilyFile);
   if(!File.Exists(path))throw new FileNotFoundException("The installed wall-drop family is missing. Reinstall TC Auto Orient.",path);
   using(var t=new Transaction(project,"TC load supplied wall-drop family")) {
    t.Start();
    Family family;
    bool loaded=project.LoadFamily(path,new PreserveValuesReload(),out family);
    // LoadFamily can return false when the identical family is already loaded.
    if(!loaded && !new FilteredElementCollector(project).OfClass(typeof(Family)).Cast<Family>().Any(f=>f.Name.Equals(BundledFamilyName,StringComparison.OrdinalIgnoreCase)))throw new InvalidOperationException("Revit could not load the supplied wall-drop family.");
    t.Commit();
   }
  }
  // Family formulas are stored in the project, so replacing the DLL alone
  // cannot repair a previously loaded family's zero-port visibility rule.
  public static bool UpgradeNumberVisibility(Document project,string folder) {
   if(project.IsFamilyDocument)return false;
   bool upgraded=false;
   foreach(var family in new FilteredElementCollector(project).OfClass(typeof(Family)).Cast<Family>().Where(Matches).ToArray())if(UpgradeNumberVisibility(project,family,folder))upgraded=true;
   return upgraded;
  }
  static bool UpgradeNumberVisibility(Document project,Family family,string folder) {
   var symbols=family.GetFamilySymbolIds().Select(project.GetElement).Cast<FamilySymbol>().ToArray();
   if(!symbols.Any(s=>s.LookupParameter(Quadrant)!=null))return false;
   if(symbols.Length>0 && symbols.All(s=>s.LookupParameter(Schema)!=null && s.LookupParameter(Schema).AsInteger()>=CurrentSchema))return false;
   var fd=project.Application.Documents.Cast<Document>().FirstOrDefault(x=>x.IsFamilyDocument && (x.Title==family.Name || x.Title==family.Name+".rfa"));
   bool closeFamily=fd==null;
   if(fd==null)fd=project.EditFamily(family);
   try {
    Directory.CreateDirectory(folder);
    fd.SaveAs(Path.Combine(folder,family.Name+".before-zero-hide-"+DateTime.Now.ToString("yyyyMMdd-HHmmss-fff")+".rfa"),new SaveAsOptions{OverwriteExistingFile=false});
    var fm=fd.FamilyManager;
    using(var t=new Transaction(fd,"TC hide zero-port numbers")) {
     t.Start();
     SetNumberVisibility(fm);
     var schema=Ensure(fm,Schema,SpecTypeId.Int.Integer,false);
     // A formula survives reloading while retaining the project's type values.
     fm.SetFormula(schema,CurrentSchema.ToString(System.Globalization.CultureInfo.InvariantCulture));
     t.Commit();
    }
    // Preserve project type values (port counts, cable IDs and other settings).
    fd.LoadFamily(project,new PreserveValuesReload());
    return true;
   } finally {if(closeFamily)fd.Close(false);}
  }
  public static void Prepare(Document familyDoc) {
   if(!familyDoc.IsFamilyDocument || !familyDoc.OwnerFamily.Name.Equals(FamilyName,StringComparison.OrdinalIgnoreCase) && !familyDoc.Title.StartsWith(FamilyName,StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Open TC - Base Wall Drop1 or select it in a project.");
   var nested=new FilteredElementCollector(familyDoc).OfClass(typeof(Family)).Cast<Family>().Single(f=>f.Name==AnnotationName);
   var ad=familyDoc.Application.Documents.Cast<Document>().FirstOrDefault(x=>x.IsFamilyDocument && (x.Title==AnnotationName || x.Title==AnnotationName+".rfa"));
   bool closeAnnotation=ad==null;
   if(ad==null)ad=familyDoc.EditFamily(nested);
   try {
    using(var t=new Transaction(ad,"TC label overflow alignment")) {
     t.Start();
     foreach(var label in new FilteredElementCollector(ad).OfClass(typeof(TextElement)).Cast<TextElement>()) {
      var vp=label.get_Parameter(BuiltInParameter.IS_VISIBLE_PARAM);
      var associated=vp==null?null:ad.FamilyManager.GetAssociatedFamilyParameter(vp);
      var role=associated==null?null:associated.Definition.Name;
      if(role==null || !role.StartsWith("Cable ID Tag")) continue;
      var wrap=label.LookupParameter("Wrap between parameters only"); if(wrap!=null)wrap.Set(1);
      var readable=label.LookupParameter("Keep Readable"); if(readable!=null)readable.Set(1);
      // The original ID labels are centred. Anchor the inner edge so overflow
      // grows away from the number/symbol. The nested annotation's Keep Readable
      // transform requires left alignment in both rotated variants.
      var desired=role=="Cable ID Tag"?HorizontalTextAlignment.Right:HorizontalTextAlignment.Left;
      if(label.HorizontalAlignment!=desired) {
       double oldFactor=label.HorizontalAlignment==HorizontalTextAlignment.Left?0:label.HorizontalAlignment==HorizontalTextAlignment.Center?0.5:1;
       double newFactor=desired==HorizontalTextAlignment.Left?0:1;
       var anchor=label.Coord+label.BaseDirection*((newFactor-oldFactor)*label.Width);
       label.HorizontalAlignment=desired;
       label.Coord=anchor;
      }
     }
     t.Commit();
    }
    ad.LoadFamily(familyDoc,new Reload());
   } finally {if(closeAnnotation)ad.Close(false);}
   var fm=familyDoc.FamilyManager;
   using(var t=new Transaction(familyDoc,"TC automatic label rules")) {
    t.Start();
    var auto=Ensure(fm,Auto,SpecTypeId.Boolean.YesNo,true);
    var quadrant=Ensure(fm,Quadrant,SpecTypeId.Int.Integer,true);
    var schema=Ensure(fm,Schema,SpecTypeId.Int.Integer,false);
    foreach(FamilyType type in fm.Types) {fm.CurrentType=type;fm.Set(auto,1);fm.Set(quadrant,0);}
    fm.SetFormula(schema,CurrentSchema.ToString(System.Globalization.CultureInfo.InvariantCulture));
    SetNumberVisibility(fm);
    for(int q=0;q<4;q++) {
     fm.SetFormula(Param(fm,Orientation.CableFlag(q)),Quadrant+" = "+q);
    }
    fm.SetFormula(Param(fm,"Shade Right"),"# of Ports > 1");
    fm.SetFormula(Param(fm,"Shade Left"),"1 = 0");
    t.Commit();
   }
  }
  public static string PrepareProject(Document project,string folder) {
   Directory.CreateDirectory(folder);
   var f=new FilteredElementCollector(project).OfClass(typeof(Family)).Cast<Family>().Single(Matches);
   var fd=project.Application.Documents.Cast<Document>().FirstOrDefault(x=>x.IsFamilyDocument && (x.Title==FamilyName || x.Title==FamilyName+".rfa"));
   bool closeFamily=fd==null;
   if(fd==null)fd=project.EditFamily(f);
   try {
    string backup=Path.Combine(folder,"TC - Base Wall Drop1.before-"+DateTime.Now.ToString("yyyyMMdd-HHmmss")+".rfa");
    fd.SaveAs(backup,new SaveAsOptions {OverwriteExistingFile=false});
    Prepare(fd);
    string result=Path.Combine(folder,FamilyName+".rfa");
    fd.SaveAs(result,new SaveAsOptions{OverwriteExistingFile=true});
    fd.LoadFamily(project,new Reload());
    using(var t=new Transaction(project,"TC orient existing wall drops")){t.Start();Engine.Sync(project);t.Commit();}
    return result;
   } finally {if(closeFamily)fd.Close(false);}
  }
  public class Reload : IFamilyLoadOptions {
   public bool OnFamilyFound(bool inUse,out bool overwrite) {overwrite=true;return true;}
   public bool OnSharedFamilyFound(Family f,bool inUse,out FamilySource source,out bool overwrite){source=FamilySource.Family;overwrite=true;return true;}
  }
  class PreserveValuesReload : IFamilyLoadOptions {
   public bool OnFamilyFound(bool inUse,out bool overwrite){overwrite=false;return true;}
   public bool OnSharedFamilyFound(Family f,bool inUse,out FamilySource source,out bool overwrite){source=FamilySource.Family;overwrite=false;return true;}
  }
 }
}
