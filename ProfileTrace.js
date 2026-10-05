.pragma library

// A visual outline, not a reconstruction of GPS elevations. Prefer PCS's
// supplied coordinates whenever available; reject ambiguous raster content.
var cache = []
function cached(source) {
    for(var i=0;i<cache.length;i++)if(cache[i].source===source)return cache[i].points
    return null
}
function remember(source,points) {
    cache=cache.filter(function(entry){return entry.source!==source})
    cache.push({source:source,points:points})
    if(cache.length>40)cache.shift()
    return points
}
function outline(pixels,width,height) {
    if(width<30 || height<20 || width*height>120000 || pixels.length!==width*height*4)return []
    function green(x,y) {
        var p=(y*width+x)*4,r=pixels[p],g=pixels[p+1],b=pixels[p+2]
        return pixels[p+3]>192 && g>70 && g-r>18 && g-b>30 && r>g*0.25
    }
    var columns=[],bottoms={}
    for(var x=0;x<width;x+=2) {
        var best=null,start=-1,last=-1
        for(var y=0;y<=height;y++) {
            if(y<height && green(x,y)) {
                if(start<0)start=y
                last=y
            } else if(start>=0 && (y-last>2 || y===height)) {
                if(last-start>=3 && (!best || last-start>best.bottom-best.top))best={x:x,top:start,bottom:last}
                start=-1
            }
        }
        if(best) {columns.push(best);bottoms[best.bottom]=(bottoms[best.bottom] || 0)+1}
    }
    var baselines=Object.keys(bottoms).map(Number)
    if(!baselines.length)return []
    var baseline=baselines.sort(function(a,b){return bottoms[b]-bottoms[a]})[0]
    var curve=columns.filter(function(c){return Math.abs(c.bottom-baseline)<=3})
    if(curve.length<width*0.35)return []
    var first=curve[0].x,last=curve[curve.length-1].x
    if(last-first<width*0.65)return []
    for(var i=1;i<curve.length;i++)if(curve[i].x-curve[i-1].x>width*0.045)return []
    var top=Math.min.apply(null,curve.map(function(c){return c.top}))
    if(baseline-top<4)return []
    return curve.map(function(c){return [Math.round((c.x-first)/(last-first)*10000)/100,
        Math.round((8+(c.top-top)/(baseline-top)*84)*100)/100]})
}
