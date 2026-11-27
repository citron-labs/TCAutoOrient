using System;
using System.Collections.Generic;
using System.Linq;
using Autodesk.Revit.DB;
namespace TCAutoOrient {
 public static class Engine {
  public static int Sync(Document d) {
   if(d.IsFamilyDocument)return 0;
   int count=0;
   foreach(var f in new FilteredElementCollector(d).OfClass(typeof(FamilyInstance)).OfCategory(BuiltInCategory.OST_DataDevices).Cast<FamilyInstance>())if(Update(f))count++;
   return count;
  }
  public static bool Update(FamilyInstance f) {
   if(!FamilySetup.Prepared(f)||f.GroupId!=ElementId.InvalidElementId)return false;
   var auto=f.LookupParameter(FamilySetup.Auto);
   if(auto==null || auto.AsInteger()!=1)return false;
   // Face-hosted orientation is more reliable than LocationPoint.Rotation.
   var facing=f.FacingOrientation;
   int q=Orientation.LabelQuadrant(facing.X,facing.Y,f.Mirrored);
   if(q<0)return false;
   var p=f.LookupParameter(FamilySetup.Quadrant);
   if(p.IsReadOnly||p.AsInteger()==q)return false;
   p.Set(q);return true;
  }
 }
 public class RotationUpdater:IUpdater {
  readonly UpdaterId id;
  public RotationUpdater(AddInId appId){id=new UpdaterId(appId,new Guid("DB71913A-9667-43EA-AD5F-B85386A934A2"));}
  public UpdaterId GetUpdaterId() { return id; }
  public ChangePriority GetChangePriority() { return ChangePriority.Annotations; }
  public string GetUpdaterName() { return "TC Wall Drop automatic labels"; }
  public string GetAdditionalInformation() { return "Keeps TC wall drop labels in their selected cardinal layout."; }
  public void Execute(UpdaterData data) {
   var d=data.GetDocument();if(d.IsFamilyDocument)return;
   var changed=data.GetAddedElementIds().Concat(data.GetModifiedElementIds()).Select(d.GetElement).ToArray();
   if(changed.OfType<FamilySymbol>().Any(s=>FamilySetup.Matches(s.Family))){Engine.Sync(d);return;}
   foreach(var f in changed.OfType<FamilyInstance>())Engine.Update(f);
  }
 }
}
