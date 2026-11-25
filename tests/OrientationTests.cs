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
  if(Orientation.NumberFlag(0)!="# of Ports Tag"||Orientation.CableFlag(3)!="Cable ID Tag - Right Rotate")throw new Exception("Variant mapping mismatch");
  Console.WriteLine($"{checks+1} orientation checks passed");
 }
}
