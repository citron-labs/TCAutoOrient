using System;
using System.IO;
using System.Linq;
using Autodesk.Revit.DB;
using Autodesk.Revit.UI;
using Autodesk.Revit.Attributes;
namespace TCAutoOrient {
 public class App:IExternalApplication {
  RotationUpdater updater;
  public Result OnStartup(UIControlledApplication a) {
   updater=new RotationUpdater(a.ActiveAddInId);
   UpdaterRegistry.RegisterUpdater(updater,true);
   var filter=new LogicalAndFilter(new ElementCategoryFilter(BuiltInCategory.OST_DataDevices),new LogicalOrFilter(new ElementClassFilter(typeof(FamilyInstance)),new ElementClassFilter(typeof(FamilySymbol))));
   UpdaterRegistry.AddTrigger(updater.GetUpdaterId(),filter,Element.GetChangeTypeAny());
   UpdaterRegistry.AddTrigger(updater.GetUpdaterId(),filter,Element.GetChangeTypeElementAddition());
   var panel=a.CreateRibbonPanel("TC Auto Orient");
   string path=typeof(App).Assembly.Location;
   panel.AddItem(new PushButtonData("TCPrepare","Prepare\nWall Drop1",path,typeof(PrepareCommand).FullName){ToolTip="Prepare TC - Base Wall Drop1 for automatic four-direction labels. Saves a family backup."});
   panel.AddItem(new PushButtonData("TCSync","Update\nLabels",path,typeof(SyncCommand).FullName){ToolTip="Synchronize all prepared TC wall drops in this project."});
   return Result.Succeeded;
  }
  public Result OnShutdown(UIControlledApplication a){if(updater!=null)UpdaterRegistry.UnregisterUpdater(updater.GetUpdaterId());return Result.Succeeded;}
 }
 [Transaction(TransactionMode.Manual)]
 public class SyncCommand:IExternalCommand {
  public Result Execute(ExternalCommandData c,ref string message,ElementSet elements){try{var d=c.Application.ActiveUIDocument.Document;using(var t=new Transaction(d,"TC update labels")){t.Start();int n=Engine.Sync(d);t.Commit();TaskDialog.Show("TC Auto Orient",n+" device layouts updated.");}return Result.Succeeded;}catch(Exception e){message=e.Message;return Result.Failed;}}
 }
 [Transaction(TransactionMode.Manual)]
 public class PrepareCommand:IExternalCommand {
  public Result Execute(ExternalCommandData c,ref string message,ElementSet elements){try{
   var d=c.Application.ActiveUIDocument.Document;
   if(d.IsFamilyDocument){FamilySetup.Prepare(d);TaskDialog.Show("TC Auto Orient","Family prepared. Save it and load it into the project. TC Label Quadrant: 0 north, 1 east, 2 south, 3 west.");}
   else {var folder=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),"TC Auto Orient",c.Application.Application.VersionNumber);string path=FamilySetup.PrepareProject(d,folder);TaskDialog.Show("TC Auto Orient","Family prepared and loaded.\n"+path);}
   return Result.Succeeded;
  }catch(Exception e){message=e.Message;return Result.Failed;}}
 }
}
