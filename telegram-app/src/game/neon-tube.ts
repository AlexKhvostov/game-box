/** NT01: reusable glass contour, no clock or game dependency. */
export const neonTubeProgress=(p:number)=>Math.max(0,Math.min(1,Number.isFinite(p)?p:0));
export function neonTubePath(width=208,height=88,radius=38):string {
  const w=Number.isFinite(width)?Math.max(24,width):208,h=Number.isFinite(height)?Math.max(24,height):88,i=6;
  const r=Math.max(0,Math.min(Number.isFinite(radius)?radius:38,(w-2*i)/2,(h-2*i)/2)),x=w-i,y=h-i;
  return `M${w/2} ${i} H${x-r} Q${x} ${i} ${x} ${i+r} V${y-r} Q${x} ${y} ${x-r} ${y} H${i+r} Q${i} ${y} ${i} ${y-r} V${i+r} Q${i} ${i} ${i+r} ${i} Z`;
}
