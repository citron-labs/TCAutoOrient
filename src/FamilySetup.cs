using System;
using System.IO;
using System.Linq;
using Autodesk.Revit.DB;
namespace TCAutoOrient {
 public static class FamilySetup {
  public const string FamilyName="TC - Base Wall Drop1";
  public const string Auto="TC Auto Orient";
  public const string Quadrant="TC Label Quadrant";
  public const string Schema="TC Auto Orient Version";
  public const string AnnotationName="TC_WALL DROP SYMBOL";
  public static bool Matches(Family f) { return f!=null && f.Name.Equals(FamilyName,StringComparison.OrdinalIgnoreCase); }
  public static bool Prepared(FamilyInstance f) { return Matches(f.Symbol.Family)&&f.LookupParameter(Quadrant)!=null; }
  static FamilyParameter Param(FamilyManager fm,string name) { return fm.Parameters.Cast<FamilyParameter>().SingleOrDefault(p=>p.Definition.Name==name); }
  static FamilyParameter Ensure(FamilyManager fm,string name,ForgeTypeId type,bool instance) { return Param(fm,name)??fm.AddParameter(name,GroupTypeId.Graphics,type,instance); }
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
    foreach(FamilyType type in fm.Types) {fm.CurrentType=type;fm.Set(auto,1);fm.Set(quadrant,0);fm.Set(schema,1);}
    for(int q=0;q<4;q++) {
     fm.SetFormula(Param(fm,Orientation.NumberFlag(q)),"and("+Quadrant+" = "+q+", not(# of Ports = 0))");
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
 }
}
