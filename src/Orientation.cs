using System;
namespace TCAutoOrient {
 public static class Orientation {
  // Clockwise from north: N=0, E=1, S=2, W=3. Tiny errors at cardinal angles are ignored.
  public static int Quadrant(double x,double y) {
   if(double.IsNaN(x)||double.IsNaN(y)||double.IsInfinity(x)||double.IsInfinity(y)||x*x+y*y<1e-12) return -1;
   double angle=Math.Atan2(x,y);
   int q=(int)Math.Floor(angle/(Math.PI/2)+0.5+1e-10);
   return (q%4+4)%4;
  }
  public static string NumberFlag(int q) { return new[]{"# of Ports Tag","# of Ports Tag - Rotate","# of Ports Tag - Left","# of Ports Tag - Left Rotate"}[q]; }
  public static string CableFlag(int q) { return new[]{"Cable ID Tag","Cable ID Tag - Rotate","Cable ID Tag - Right","Cable ID Tag - Right Rotate"}[q]; }
 }
}
