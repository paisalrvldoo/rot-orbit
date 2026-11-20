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
local NumberSequenceKeypoint={new=function() end}
local Random={new=function()
 local state=73126
 return {NextNumber=function(_,min,max)
  state=(state*16807)%2147483647
  min,max=min or 0,max or 1
  return min+(max-min)*state/2147483647
 end}
end}
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
local Color3={fromRGB=function(r,g,b) return setmetatable({r,g,b},color) end}
local function enum() return setmetatable({},{__index=function(t,k) local v=enum();rawset(t,k,v);return v end}) end
local Enum=enum()
local Instance={}
function Instance.new(class,parent)
 local item={ClassName=class,Children={},Attributes={}}
 if class=='Atmosphere' then item.Density=0.395 end
 function item:GetChildren() return self.Children end
 function item:IsA(class) return self.ClassName==class or class=='BasePart' and self.ClassName=='Part' end
 function item:FindFirstChild(name) for _,v in ipairs(self.Children) do if v.Name==name then return v end end end
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
 p.Shape=shape
 table.insert(parts,p);return p
end
${section(builder, 'function WorldBuilder.Ring(', 'function WorldBuilder.Billboard(')}
local Lighting=Instance.new('Lighting')
${section(builder, 'local function lighting()', 'local function signFace(')}
lighting()
for _,effect in ipairs(Lighting:GetChildren()) do
 assert(not effect:IsA('Atmosphere') or effect.Density<=0,'positive Lighting atmosphere washes out the black sky')
end
for _,ambient in ipairs({Lighting.Ambient,Lighting.OutdoorAmbient}) do
 for _,channel in ipairs(ambient) do assert(channel>=40 and channel<=60,'space ambient must stay within RGB 40–60') end
end
local sky=Lighting:FindFirstChild('OrbitSky')
assert(sky and sky.StarCount>=3000 and not sky.CelestialBodiesShown,'keep the rich night sky')
local space=folder('SkyCheck')
skyAndPlanet(space)
local planets=space:FindFirstChild('Starfield'):FindFirstChild('BackdropPlanets')
assert(planets and #planets:GetChildren()>=4,'expected authored backdrop bodies')
for _,body in ipairs(planets:GetChildren()) do
 local p=body.Position
 local horizontal=math.sqrt(p.X^2+p.Z^2)
 local radius=math.max(body.Size.X,body.Size.Y,body.Size.Z)/2
 assert(p.Y+radius<=0 or horizontal>=1000,body.Name..' rises above deck within 1000 studs of the hub')
end
local azure=planets:FindFirstChild('AzureHeroPlanet')
local rim=planets:FindFirstChild('AzureRim')
assert(azure.Shape==Enum.PartType.Ball and azure.Position.Y+azure.Size.Y/2<0,'Azure belongs below the horizon')
assert(rim.Material==Enum.Material.SmoothPlastic and rim.Transparency>=0.9,'Azure rim must stay faint and non-emissive')
table.clear(parts)
print('Sky checks passed: no positive atmosphere, dark ambient, built-in stars and distant backdrop planets.')
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
local viewFov=65
local function project(p, width, height)
 width,height=width or 1170,height or 540
 local q=camera:PointToObjectSpace(p);local depth=-q.Z
 assert(depth>0,'review geometry is behind arrival camera')
 local focal=(height/2)/math.tan(math.rad(viewFov/2))
 return width/2+focal*q.X/depth,height/2-focal*q.Y/depth
end
local loX,hiX,loY,hiY=math.huge,-math.huge,math.huge,-math.huge
for _,p in ipairs(parts) do
 if p.Parent.Name=='TrackChassis' then
  assert(p.CanCollide,'shopping track must be walkable')
  assert(p.Position.Y>4 and p.Position.Y<19,'shopping track must stay near deck level')
  local x,y=project(p.Position);loX,hiX=math.min(loX,x),math.max(hiX,x);loY,hiY=math.min(loY,y),math.max(hiY,y)
 end
end
assert(hiX-loX>=1170*0.6,'orbit must span at least 60% of the phone frame')
assert(loY>155 and hiY<490,'arrival cargo rail must clear the HUD and fit above the controls')
assert(hiY-loY>100,'the low cargo track must still project as a visible arc')
local title=named('TitlePanel')[1]
local halos={};local haloCount=0;local reverse=false
for _,arc in ipairs(named('CelestialEnergyArc')) do
 assert(not arc.CanCollide,'sky halo must never block players')
 assert(arc.Position.Y>56,'celestial halo must stay above the portal and hologram')
 local halo=arc.Parent
 if not halos[halo] then
  halos[halo]=true;haloCount+=1
  local speed=halo:GetAttribute('HaloSpeed')
  assert(speed and math.abs(speed)<0.05,'celestial halo must rotate slowly')
  local pivot=halo:GetAttribute('HaloFrame').Position
  assert(pivot.X==0 and pivot.Z==0 and pivot.Y>Config.World.RailHeight+40 and pivot.Y>=70 and pivot.Y<=90,'sky halo must orbit high above the hub centre')
  if speed<0 then reverse=true end
 end
end
assert(haloCount==3 and reverse,'three celestial halos must counterrotate')
local outerRims=0
for _,arc in ipairs(parts) do if arc.Parent.Name=='WarpOuterCrown' then outerRims+=1 end end
assert(outerRims==112,'both portals need two additional deep outer rims')
local core=named('HologramGlobe')[1].Position
assert(core.X==0 and core.Z==0 and core.Y>=44,'the hologram must rise high above the hub centre')
assert(Config.World.RailTilt==0 and Config.World.RailHeight>=8 and Config.World.RailHeight<=10,
 'the cargo rail must be flat and 8–10 studs above the deck')
assert(Config.World.RailPlane().Position.X==0 and Config.World.RailPlane().Position.Z==0,
 'the cargo ring must also share the hub centre')
assert(#named('HologramSatellite')==3,'hologram needs three orbital energy shards')
for _,p in ipairs(corners(title)) do
	local x,y=project(p);assert(x>120 and x<1050 and y>145 and y<455,'title must stay below the HUD and inside the clear phone region')
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
for _,support in ipairs(named('TitleSupport')) do
	local low,high=bounds(support)
	assert(high.X<tl.X or low.X>th.X,'title support must sit outside the sign face')
end
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
 assert(low.Y<0.2 and high.Y>6 and high.Y<12,'ramp must connect deck and low shopping track')
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
-- Execute the actual cover staging and marquee restoration, not copied poses.
local UDim2={fromOffset=function(x,y) return {Width=x,Height=y} end}
local ScreenshotService=(function()
${section(read('src/server/ScreenshotService.luau'), 'local ScreenshotService =')}
end)()
local screenshots=setmetatable({Bases={World=world}},ScreenshotService)
local liveTitle=title.CFrame
screenshots:StageTitle('Cover')
local coverTitle=title.CFrame
screenshots:StageTitle('Cover')
assert((title.CFrame.Position-coverTitle.Position).Magnitude<0.001,'repeat Cover must not drift the title')
for _,shot in ipairs({'Index','Raid','Upgrades'}) do
 screenshots:StageTitle(shot)
 assert((title.CFrame.Position-liveTitle.Position).Magnitude<0.001,'other presets must restore live title')
end
screenshots:StageTitle('Cover')
local state={Bay={Slots={}}}
for i,name in ipairs({'Epic','Cosmic','SECRET','Cosmic','SECRET'}) do
 local pillar={Attachment1={Position=Vector3.new(0,24.675,2)}}
 local model={PrimaryPart={BrainrotBillboard={},FindFirstChild=function() return name=='SECRET' and pillar or nil end}}
 function model:GetAttribute() return name end
 function model:SetAttribute(k,v) self[k]=v end
 function model:PivotTo(f) self.Frame=f end
 state.Bay.Slots[i]={Occupant={Model=model}}
end
function WorldBuilder.ColorSocket() end
local rootPart={}
local effects=folder('PreviewEffects')
local meteorCount=0
local meteors={Effects=effects,CreateMeteor=function() meteorCount+=1 end}
-- stageCover is private; Prepare's source invokes it via this tiny exported
-- test closure. No runtime API is added for the source harness.
local stageSource=[==[${section(read('src/server/ScreenshotService.luau'), 'local function pose(', 'function ScreenshotService.new(')}]==]
local stage=assert(loadstring(stageSource..' return stageCover'))
-- loadstring has no access to our lexical builder/config; use setfenv.
setfenv(stage,setmetatable({WorldBuilder=WorldBuilder,Config=Config,Rarity=Rarity,
 CFrame=CFrame,Vector3=Vector3,UDim2=UDim2,Color3=Color3,Enum=Enum,Instance=Instance},{__index=getfenv()}))
camera,viewFov=stage()(state,rootPart,meteors)
assert(viewFov==55 and meteorCount==4)
for _,point in ipairs(corners(title)) do
 local x,y=project(point,1280,720)
 assert(x>440 and x<860 and y>151 and y<240,'cover marquee must clear money/event HUD')
end
local signLow,signHigh=math.huge,-math.huge
for _,point in ipairs(corners(title)) do
 local _,y=project(point,1280,720);signLow,signHigh=math.min(signLow,y),math.max(signHigh,y)
end
for _,slot in ipairs(state.Bay.Slots) do
 local model=slot.Occupant.Model
 local pillar=model.PrimaryPart:FindFirstChild('SecretLightPillar')
 if pillar then
  assert(pillar.Attachment1.Position.Y==12,'foreground SECRET beam must stop above crown')
  local _,top=project(model.Frame.Position+pillar.Attachment1.Position,1280,720)
  assert(top>signHigh+12,'foreground beam must not cross the world marquee')
 end
end
-- Check actual solid rails/pylons and balcony scenery against the moved sign.
for _,p in ipairs(parts) do
 if p.Parent.Name~='StationTitle' and (p.Transparency or 0)<0.7 then
  for x=-18,18,3 do
   local target=title.CFrame*Vector3.new(x,0,title.Size.Z/2)
   assert(not blocksSightline(p,camera.Position,target),p.Name..' blocks cover title')
  end
 end
end
local minRail,maxRail=math.huge,-math.huge
for _,p in ipairs(parts) do if p.Parent.Name=='TrackChassis' then
 local x=project(p.CFrame.Position,1280,720);minRail,maxRail=math.min(minRail,x),math.max(maxRail,x)
end end
assert(maxRail-minRail>1280*0.6,'cover must be dominated by the real orbit')
local lastRight=-math.huge
for _,slot in ipairs(state.Bay.Slots) do
 local model=slot.Occupant.Model
 local card=model.PrimaryPart.BrainrotBillboard
 local x,y=project(model.Frame.Position+card.StudsOffsetWorldSpace,1280,720)
 assert(x-card.Size.Width/2>lastRight,'five dock value cards must not overlap')
 assert(y-card.Size.Height/2>420 and y+card.Size.Height/2<598,'dock cards must clear faces and counts strip')
 lastRight=x+card.Size.Width/2
end
local hero=state.Bay.Slots[3].Occupant.Model.Frame.Position
local _,foot=project(hero,1280,720)
local _,crown=project(hero+Vector3.new(0,4.35*Rarity.ByName.SECRET.Scale,0),1280,720)
assert(foot-crown>=720*0.24,'docked SECRET must be a cover hero, not a distant speck')
print('Cover source checks passed: elevated balcony, real orbit width, clear marquee, five separated cards and repeatable title restoration. NOT a rendered screenshot.')
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
