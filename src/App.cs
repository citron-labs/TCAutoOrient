using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Autodesk.Revit.DB;
using Autodesk.Revit.UI;
using Autodesk.Revit.DB.Events;
using Autodesk.Revit.UI.Events;
namespace TCAutoOrient {
 public class App:IExternalApplication {
  RotationUpdater updater;
  readonly HashSet<Document> pending=new HashSet<Document>();
  readonly HashSet<Document> familyLoaded=new HashSet<Document>();
  bool initialScan=true;
  bool upgrading;
  public Result OnStartup(UIControlledApplication a) {
   updater=new RotationUpdater(a.ActiveAddInId);
   UpdaterRegistry.RegisterUpdater(updater,true);
   var filter=new LogicalAndFilter(new ElementCategoryFilter(BuiltInCategory.OST_DataDevices),new LogicalOrFilter(new ElementClassFilter(typeof(FamilyInstance)),new ElementClassFilter(typeof(FamilySymbol))));
   UpdaterRegistry.AddTrigger(updater.GetUpdaterId(),filter,Element.GetChangeTypeAny());
   UpdaterRegistry.AddTrigger(updater.GetUpdaterId(),filter,Element.GetChangeTypeElementAddition());
   a.ControlledApplication.DocumentOpened+=DocumentOpened;
   a.ControlledApplication.DocumentCreated+=DocumentCreated;
   a.ControlledApplication.DocumentChanged+=DocumentChanged;
   a.Idling+=UpgradePendingProjects;
   return Result.Succeeded;
  }
  void DocumentOpened(object sender,DocumentOpenedEventArgs e){pending.Add(e.Document);}
  void DocumentCreated(object sender,DocumentCreatedEventArgs e){pending.Add(e.Document);}
  void DocumentChanged(object sender,DocumentChangedEventArgs e) {
   if(upgrading)return;
   var d=e.GetDocument();
   if(d.IsFamilyDocument)return;
   // A prepared family may be loaded into a project after it was opened.
   if(e.GetAddedElementIds().Concat(e.GetModifiedElementIds()).Select(d.GetElement).Any(x=>
    x is Family && FamilySetup.Matches((Family)x) ||
    x is FamilySymbol && FamilySetup.Matches(((FamilySymbol)x).Family) ||
    x is FamilyInstance && FamilySetup.Prepared((FamilyInstance)x)))pending.Add(d);
  }
  void UpgradePendingProjects(object sender,IdlingEventArgs e) {
   if(upgrading)return;
   var ui=sender as UIApplication;
   if(ui==null)return;
   familyLoaded.RemoveWhere(d=>!d.IsValidObject);
   if(initialScan){foreach(Document d in ui.Application.Documents)pending.Add(d);initialScan=false;}
   foreach(var d in pending.ToArray()) {
    if(!d.IsValidObject || d.IsFamilyDocument){pending.Remove(d);continue;}
    if(d.IsReadOnly || d.IsModifiable)continue;
    // Family editing/reloading must run in a writable API context, outside
    // DocumentOpened, DocumentChanged and the dynamic model updater.
    pending.Remove(d);
    upgrading=true;
    try {
     var folder=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),"TC Auto Orient",ui.Application.VersionNumber);
     if(!familyLoaded.Contains(d))FamilySetup.LoadBundledFamily(d);
     FamilySetup.UpgradeNumberVisibility(d,folder);
     using(var t=new Transaction(d,"TC automatic label update")){t.Start();Engine.Sync(d);t.Commit();}
     familyLoaded.Add(d);
    } catch(Exception ex) {
     ui.Application.WriteJournalComment("TC Auto Orient automatic upgrade failed: "+ex.ToString(),false);
     TaskDialog.Show("TC Auto Orient","Automatic family setup could not finish in "+d.Title+".\n"+ex.Message+"\nResolve the issue and reopen the project to retry.");
    } finally {upgrading=false;}
   }
  }
  public Result OnShutdown(UIControlledApplication a){
   a.Idling-=UpgradePendingProjects;
   a.ControlledApplication.DocumentOpened-=DocumentOpened;
   a.ControlledApplication.DocumentCreated-=DocumentCreated;
   a.ControlledApplication.DocumentChanged-=DocumentChanged;
   pending.Clear();
   familyLoaded.Clear();
   if(updater!=null)UpdaterRegistry.UnregisterUpdater(updater.GetUpdaterId());return Result.Succeeded;
  }
 }
}
