using System;
using TCAutoOrient;
class Tests {
 static int checks;
 static void Equal(int expected,int actual){checks++;if(expected!=actual)throw new Exception($"Expected {expected}, got {actual}");}
 static void Main(){
  for(int q=0;q<4;q++)for(int rotation=-3;rotation<=3;rotation++)foreach(double offset in new[]{-44.9,0,44.9}) {
   double angle=(q*90+360*rotation+offset)*Math.PI/180;
   Equal(q,Orientation.Quadrant(Math.Sin(angle),Math.Cos(angle)));
  }
  Equal(-1,Orientation.Quadrant(0,0));Equal(-1,Orientation.Quadrant(double.NaN,0));Equal(-1,Orientation.Quadrant(0,double.PositiveInfinity));
  // Every former layout must use its opposite label pair, preserving rotation.
  // These checks verify the requested swap, not Revit's rendered output.
  foreach(bool mirrored in new[]{false,true})for(int direction=0;direction<4;direction++)foreach(double offset in new[]{-44.9,0,44.9}) {
   double angle=(direction*90+offset)*Math.PI/180;
   double facingX=Math.Sin(angle),facingY=Math.Cos(angle);
   int layout=Orientation.LabelQuadrant(facingX,facingY,mirrored);
   int previousLayout=(direction+(mirrored?2:0))%4;
   Equal((previousLayout+2)%4,layout);
   Equal(previousLayout%2,layout%2);
  }
  Equal(-1,Orientation.LabelQuadrant(0,0,true));
  Equal(-1,Orientation.LabelQuadrant(double.NaN,0,true));
  Equal(-1,Orientation.LabelQuadrant(0,double.PositiveInfinity,true));
  if(Orientation.NumberFlag(0)!="# of Ports Tag"||Orientation.CableFlag(3)!="Cable ID Tag - Right Rotate")throw new Exception("Variant mapping mismatch");
  Console.WriteLine($"{checks+1} orientation checks passed");
 }
}
