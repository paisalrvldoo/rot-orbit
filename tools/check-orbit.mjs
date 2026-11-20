// Geometry checks for the owner's 0a gate. Executes the actual Luau builders;
// projections are diagnostics, never a substitute for a genuine Studio shot.
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = dirname(dirname(fileURLToPath(import.meta.url)));
const read = path => readFileSync(join(root, path), 'utf8');
const section = (source, start, end) => source.slice(source.indexOf(start), end ? source.indexOf(end) : undefined);
const builder = read('src/server/WorldBuilder.luau');
const harness = `
local Vector3 = {}
local vm = {}
function Vector3.new(x, y, z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vm) end
function vm.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vm.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vm.__unm(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
function vm.__mul(a,b) if type(a)=='number' then a,b=b,a end return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
function vm.__div(a,b) return a*(1/b) end
local function dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
local function cross(a,b) return Vector3.new(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end
function vm.__index(a,k)
 if k=='Magnitude' then return math.sqrt(dot(a,a)) end
 if k=='Unit' then return a/a.Magnitude end
end
Vector3.zero,Vector3.one=Vector3.new(),Vector3.new(1,1,1)
Vector3.xAxis,Vector3.yAxis,Vector3.zAxis=Vector3.new(1,0,0),Vector3.new(0,1,0),Vector3.new(0,0,1)
local Vector2,ColorSequence,NumberSequence,NumberRange = {new=Vector3.new},{new=function() end},{new=function() end},{new=function() end}
local CFrame={}; local cm={}
local function frame(p,r,u,b) return setmetatable({Position=p,R=r,U=u,B=b},cm) end
function CFrame.new(x,y,z)
 return frame(type(x)=='table' and x or Vector3.new(x,y,z),Vector3.xAxis,Vector3.yAxis,Vector3.zAxis)
end
local function rotate(c,p) return c.R*p.X+c.U*p.Y+c.B*p.Z end
function cm.__mul(a,b)
 if b.R then return frame(a.Position+rotate(a,b.Position),rotate(a,b.R),rotate(a,b.U),rotate(a,b.B)) end
 return a.Position+rotate(a,b)
end
function cm.__index(c,k)
 if k=='LookVector' then return -c.B end
 if k=='PointToObjectSpace' then return function(_,p) local d=p-c.Position;return Vector3.new(dot(d,c.R),dot(d,c.U),dot(d,c.B)) end end
end
function CFrame.Angles(x,y,z)
 local sx,cx,sy,cy,sz,cz=math.sin(x),math.cos(x),math.sin(y),math.cos(y),math.sin(z),math.cos(z)
 return frame(Vector3.zero,Vector3.new(1,0,0),Vector3.new(0,cx,sx),Vector3.new(0,-sx,cx))
 *frame(Vector3.zero,Vector3.new(cy,0,-sy),Vector3.yAxis,Vector3.new(sy,0,cy))
 *frame(Vector3.zero,Vector3.new(cz,sz,0),Vector3.new(-sz,cz,0),Vector3.zAxis)
end
function CFrame.lookAt(p,t,up)
 local b=(p-t).Unit;local r=cross(up or Vector3.yAxis,b).Unit;return frame(p,r,cross(b,r),b)
end
CFrame.identity=CFrame.new()
local color={};color.__index=color
function color:Lerp(b,t) return setmetatable({},color) end
local Color3={fromRGB=function() return setmetatable({},color) end}
local function enum() return setmetatable({},{__index=function(t,k) local v=enum();rawset(t,k,v);return v end}) end
local Enum=enum()
local Instance={}
function Instance.new(class,parent)
 local item={ClassName=class,Children={},Attributes={}}
 function item:GetChildren() return self.Children end
 function item:SetAttribute(k,v) self.Attributes[k]=v end
 function item:GetAttribute(k) return self.Attributes[k] end
 function item:GetAttributeChangedSignal() return {Connect=function() end} end
 setmetatable(item,{__newindex=function(t,k,v) rawset(t,k,v);if k=='Parent' and v then table.insert(v.Children,t) end end})
 item.Parent=parent
 return item
end
local CollectionService={AddTag=function() end}
local Config=(function() ${section(read('src/shared/Config.luau'), 'local Config =')} end)()
local Rarity=(function() ${section(read('src/shared/BrainrotTraits.luau'), 'local Rarity =')} end)().Rarity
local palette=Config.Palette
local WorldBuilder={};local parts={}
local function folder(name,parent) local f=Instance.new('Folder',parent);f.Name=name;return f end
function WorldBuilder.Part(name,size,cf,color,material,parent,shape,solid)
 local p=Instance.new('Part',parent)
 p.Name,p.Size,p.CFrame,p.Position,p.Color,p.Material,p.CanCollide=name,size,cf,cf.Position,color,material,solid~=false
 table.insert(parts,p);return p
end
${section(builder, 'function WorldBuilder.Ring(', 'function WorldBuilder.Billboard(')}
local function signFace() return {} end
${section(builder, 'local function buildTitle(', 'function WorldBuilder.CreatePedestal(')}
${section(builder, 'local function buildCargoRing(', 'local function buildDomes(')}
local world={Root=folder('ROT_ORBIT'),Geometry=folder('Station')}
buildCargoRing(world)
local function named(name)
 local found={};for _,p in ipairs(parts) do if p.Name==name then table.insert(found,p) end end;return found
end
local function corners(p)
 local result={};for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
 table.insert(result,p.CFrame*Vector3.new(p.Size.X*x/2,p.Size.Y*y/2,p.Size.Z*z/2))
 end end end;return result
end
local camera=Config.World.SpawnCamera()
local function project(p)
 local q=camera:PointToObjectSpace(p);local depth=-q.Z
 assert(depth>0,'review geometry is behind arrival camera')
 local focal=270/math.tan(math.rad(65/2))
 return 585+focal*q.X/depth,270-focal*q.Y/depth
end
local loX,hiX,loY,hiY=math.huge,-math.huge,math.huge,-math.huge
for _,p in ipairs(parts) do
 if p.Parent.Name=='TrackChassis' then
  assert(p.CanCollide,'elevated shopping track must be walkable')
  assert(p.Position.Y>24,'cargo orbit regressed to floor level')
  local x,y=project(p.Position);loX,hiX=math.min(loX,x),math.max(hiX,x);loY,hiY=math.min(loY,y),math.max(hiY,y)
 end
end
assert(hiX-loX>=1170*0.6,'orbit must span at least 60% of the phone frame')
assert(loY>90 and hiY<270,'arrival orbit must arc in the upper half below the money area')
assert(hiY-loY>110,'orbit must have a visible elevated arc, not a flat horizon line')
local title=named('TitlePanel')[1]
for _,p in ipairs(corners(title)) do
 local x,y=project(p);assert(x>120 and x<1050 and y>120 and y<470,'title escapes its clear phone region')
end
-- Conservative world AABBs: reject any track component intersecting the title.
local function bounds(part)
 local low,high=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,p in ipairs(corners(part)) do
  low=Vector3.new(math.min(low.X,p.X),math.min(low.Y,p.Y),math.min(low.Z,p.Z))
  high=Vector3.new(math.max(high.X,p.X),math.max(high.Y,p.Y),math.max(high.Z,p.Z))
 end
 return low,high
end
local tl,th=bounds(title)
local function blocksSightline(part, origin, target)
 local start=part.CFrame:PointToObjectSpace(origin)
 local delta=part.CFrame:PointToObjectSpace(target)-start
 local first,last=0,1
 for _,axis in ipairs({'X','Y','Z'}) do
  local half=part.Size[axis]/2
  if math.abs(delta[axis])<1e-8 then
   if math.abs(start[axis])>half then return false end
  else
   local a,b=(-half-start[axis])/delta[axis],(half-start[axis])/delta[axis]
   first,last=math.max(first,math.min(a,b)),math.min(last,math.max(a,b))
   if first>last then return false end
  end
 end
 return true
end
local titleSightlines={}
for x=-20,20,2 do
 for y=-3.3,3.3,1.65 do
  table.insert(titleSightlines,title.CFrame*Vector3.new(x,y,title.Size.Z/2))
 end
end
for _,p in ipairs(parts) do
 if p.Parent.Name~='StationTitle' then
  local low,high=bounds(p)
  assert(high.X<tl.X or low.X>th.X or high.Y<tl.Y or low.Y>th.Y or high.Z<tl.Z or low.Z>th.Z,
   p.Name..' intersects the station title')
  -- The title camera also slides two studs in either direction before Play.
  if high.Y>=math.min(tl.Y,camera.Position.Y) and low.Y<=math.max(th.Y,camera.Position.Y)
   and high.Z>=tl.Z and low.Z<=camera.Position.Z then
   for slide=-2,2,2 do
    local origin=camera*Vector3.new(slide,0,0)
    for _,target in ipairs(titleSightlines) do
     assert(not blocksSightline(p,origin,target),p.Name..' obscures the title from arrival')
    end
   end
  end
 end
end
local ramps=named('CargoAccessRamp');assert(#ramps==2)
for _,r in ipairs(ramps) do
 assert(r.CanCollide and r.Size.X>=8,'cargo ramp must be solid and broad')
 local low=r.CFrame*Vector3.new(0,0,r.Size.Z/2)
 local high=r.CFrame*Vector3.new(0,0,-r.Size.Z/2)
 local d=high-low;local slope=math.deg(math.atan2(d.Y,math.sqrt(d.X*d.X+d.Z*d.Z)))
 assert(slope>0 and slope<35,'ramp is too steep for a carrying player')
 assert(low.Y<0.2 and high.Y>25,'ramp must connect deck and elevated shopping track')
 assert(math.abs(math.sqrt(high.X^2+high.Z^2)-Config.World.RailRadius)<6,'ramp misses ring')
 local pod=Config.World.RailFrame(math.atan2(high.Z/math.cos(Config.World.RailTilt),high.X),Config.World.RailRadius,Config.Conveyor.HoverHeight).Position
 assert((pod-(high+Vector3.new(0,3,0))).Magnitude<Config.InteractionDistance,'ordinary buy range must still reach cargo')
end
local gate=world.CargoEntry:GetAttribute('GateFrame')
local entry=Config.World.RailFrame(Config.World.CargoEntryAngle,Config.World.RailRadius,0).Position
local delta=gate:PointToObjectSpace(entry)
assert(math.abs(delta.Y)<0.01 and math.abs(delta.X)<0.01,'live arrival must pass through the actual portal plane')
local aperture
for _,p in ipairs(parts) do if p.Parent.Name=='WarpAperture' then aperture=p;break end end
local portalRadius=(aperture.Position-gate.Position).Magnitude
local crownHeight=4.35*Rarity.ByName.SECRET.Scale*Config.Conveyor.ModelScale+Config.Conveyor.HoverHeight
local crownLocal=gate:PointToObjectSpace(entry+Vector3.new(0,crownHeight,0))
assert(math.sqrt(crownLocal.X^2+crownLocal.Z^2)+0.8<portalRadius,'enlarged SECRET crown clips portal rim')
print(string.format('Orbit geometry checks passed: 1170x540 rail x%.0f–%.0f y%.0f–%.0f, two walkable ramps, clear orbit-to-title sightlines and SECRET portal headroom. NOT a rendered screenshot.',loX,hiX,loY,hiY))
`;
const scratch = join(root, 'out', 'orbit-check');
mkdirSync(scratch, { recursive: true });
const path = join(scratch, 'check.luau');
writeFileSync(path, harness);
const result = spawnSync('luau', [path], { encoding: 'utf8', cwd: root });
process.stdout.write(result.stdout ?? '');
process.stderr.write(result.stderr ?? '');
if (result.error || result.status !== 0) throw result.error ?? new Error('Orbit geometry checks failed');
