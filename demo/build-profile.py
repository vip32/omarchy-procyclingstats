#!/usr/bin/python3
"""Rebuild the fictional PNG fallback fixture using only Python's standard library."""
import base64
import json
from pathlib import Path
import struct
import zlib

fixture=Path(__file__).with_name('fixtures')/'example.json'
data=json.loads(fixture.read_text())
width,height=600,240
# Fictional elevation percentages, not real race or GPS data.
points=[(0,75),(60,72),(120,48),(180,60),(240,32),(300,58),(360,65),(420,42),(480,56),(540,70),(599,75)]
rows=[]
for y in range(height):
    row=bytearray([0])
    for x in range(width):
        left,right=next((a,b) for a,b in zip(points,points[1:]) if a[0]<=x<=b[0])
        level=left[1]+(right[1]-left[1])*(x-left[0])/(right[0]-left[0])
        edge=round(25+level*1.8)
        color=(142,190,45) if edge<=y<220 else (215,220,225) if y==220 or y%50==0 or x%100==0 else (255,255,255)
        row.extend(color)
    rows.append(bytes(row))
def chunk(kind,body):
    return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows)))+chunk(b'IEND',b'')
course=data['details']['race/demo-city-circuit/2026/result']
course.update(profile=[],profileImage='data:image/png;base64,'+base64.b64encode(png).decode('ascii'),profileImageWidth=width,profileImageHeight=height,profileState='ready')
fixture.write_text(json.dumps(data,indent=2)+'\n')
