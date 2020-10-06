
-- glitchlets v0.1.0
-- lets glitch
-- with
-- glitchlets
--
-- llllllll.co/t/glitchlets
--
--    ▼ instructions below ▼
--

-- state variable
s={
  v={},-- voices to be initialized in init()
  amps={},--store amp information
  update_ui=false,-- toggles redraw
  update_parameters=false,
  recording=false,-- recording state
  force_recording=false,
  loop_end=0,-- amount recorded into buffer
  shift=false,
  monitor=false,
  message="",
  ready=false,
  current_beat=0,
  current_note=0,
  i=2,
  resolution=0.025,
  minimum_quantized=0.125,-- miniumum quantization is 1/8th notes
  loop_time=0,
}

-- constants
function init()
  params:add_separator("glitchlets")
  params:add_control("loop length","loop length",controlspec.new(0,64,'lin',1,4,'beats'))
  params:set_action("loop length",update_loop_length_and_update)
  
  for i=1,6 do
    params:add_group("glitchlet "..i,8)
    params:add_option(i.."active",i.."active",{"no","yes"},1)
    params:set_action(i.."active",update_parameters)
    params:add_taper(i.."volume","volume",0,1,0,0.5,"")
    params:set_action(i.."volume",update_parameters)
    params:add_control(i.."reset every",i.."reset every",controlspec.new(0,64,'lin',1,4,'beats'))
    params:set_action(i.."reset every",update_parameters)
    params:add_control(i.."probability",i.."probability",controlspec.new(0,100,'lin',1,100,'%'))
    params:set_action(i.."probability",update_parameters)
    params:add_control(i.."sample start",i.."sample start",controlspec.new(0,64,'lin',1,0,'beats'))
    params:set_action(i.."sample start",update_parameters)
    params:add_control(i.."sample length",i.."sample length",controlspec.new(0,64,'lin',1,1,'beats'))
    params:set_action(i.."sample length",update_parameters)
    params:add_control(i.."glitch start",i.."glitch start",controlspec.new(0,64,'lin',1,0,'beats'))
    params:set_action(i.."glitch start",update_parameters)
    params:add_control(i.."glitches",i.."glitches",controlspec.new(0,64,'lin',1,1,'x'))
    params:set_action(i.."glitches",update_parameters)
  end
  
  params:read(_path.data..'glitchlets/'.."glitchlets.pset")
  
  for i=1,6 do
    s.v[i]={}
    s.v[i].active=0
    s.v[i].volume=0
    s.v[i].position=0
    s.v[i].probability=0
    s.v[i].sample_start=0
    s.v[i].sample_length=0
    s.v[i].sample_end=0
    s.v[i].glitch_start=0
    s.v[i].glitches=0
    s.v[i].glitch_num=0
    s.v[i].reset_every=0
  end
  
  -- initialize softcut
  for i=1,6 do
    if i==1 then
      -- voice 1 records into buffer, but does not play
      softcut.level(i,0)
      softcut.level_input_cut(1,i,1)
      softcut.level_input_cut(2,i,1)
      softcut.rec_level(i,1)
      softcut.pre_level(i,0)
    else
      softcut.level(i,1)
      softcut.level_input_cut(1,i,0)
      softcut.level_input_cut(2,i,0)
    end
    softcut.pan(i,0)
    softcut.play(i,0)
    softcut.rec(i,0)
    softcut.rate(i,1)
    softcut.loop_start(i,0)
    softcut.loop_end(i,30)
    softcut.loop(i,1)
    
    softcut.fade_time(i,0.2)
    softcut.level_slew_time(i,2)
    softcut.rate_slew_time(i,2)
    
    softcut.buffer(i,1)
    softcut.position(i,0)
    softcut.enable(i,1)
  end
  update_loop_length(params:get("loop length"))
  
  -- initialize timers
  -- initialize timer for updating screen
  timer=metro.init()
  timer.time=s.resolution
  timer.count=-1
  timer.event=update_main
  timer:start()
  
  -- position poll
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
  
  -- amplitude poll
  p_amp_in=poll.set("amp_in_l")
  p_amp_in.time=s.resolution
  p_amp_in.callback=update_amp
  p_amp_in:start()
  
  -- monitor input
  audio.level_monitor(1)
end

--
-- updaters
--
function update_parameters(x)
  s.update_parameters=true
  params:write(_path.data..'glitchlets/'.."glitchlets.pset")
end

function update_positions(i,x)
  s.v[i].position=x
  if i==s.i then
    s.update_ui=true
  end
end

function update_main()
  if s.update_ui then
    redraw()
  end
  if math.floor(clock.get_beats())%params:get("loop length")==0 then
    -- reset amplitude time
    s.loop_time=0
  end
  -- TODO
  -- check all parameters for each voice and update
  -- if it has changed
  if s.update_parameters then
    for i=2,6 do
      if s.v[i].sample_start~=params:get(i.."sample start") || s.v[i].sample_length~=params:get(i.."sample length") || then
        s.v[i].sample_start=params:get(i.."sample start")
        s.v[i].sample_length=params:get(i.."sample length")
        s.v[i].sample_end=clock.get_beat_sec()*(s.v[i].sample_start+s.v[i].sample_end)
        softcut.loop_start(i,clock.get_beat_sec()*s.v[i].sample_start)
        softcut.loop_end(i,s.v[i].sample_end)
        softcut.position(i,clock.get_beat_sec()*s.v[i].sample_start)
      end
      if s.v[i].volume~=params:get(i.."volume") then
        s.v[i].volume=params:get(i.."volume")
        softcut.level(i,s.v[i].volume)
      end
      if s.v[i].probability~=params:get(i.."probability") then
        s.v[i].probability=params:get(i.."probability")
      end
      if s.v[i].active~=(params:get(i.."active")==2) then
        s.v[i].active=(params:get(i.."active")==2)
      end
    end
  end
  -- TODO: if active
  -- check if its ready to activate
  for i=2,6 do
    if s.v[i].active then
      
    end
  end
  
end

function update_amp(val)
  -- toggle recording on with incoming amplitude
  -- toggle recording off with silence
  s.amps[round_to_nearest(s.v[1].position,s.minimum_quantized)]=val
  s.update_ui=true
end

function update_loop_length(x)
  -- rebuild table
  s.amps={}
  for i=1,(clock.get_beat_sec()*x)/s.minimum_quantized do
    table.insert(s.amps,0)
  end
  softcut.loop_end(1,clock.get_beat_sec()*x)
end

function update_loop_length_and_update(x)
  update_loop_length(x)
  update_parameters(0)
end
--
-- input
--

function key(n,z)
  if n==1 then
    if z==1 then
      s.shift=true
    else
      s.shift=false
    end
  end
  s.update_ui=true
end

function enc(n,d)
  if s.shift and n==1 then
  end
  s.update_ui=true
end
--
-- screen
--
function redraw()
  s.update_ui=false
  screen.clear()
  
  shift=0
  if s.shift then
    shift=5
  end
  
  if s.message~="" then
    screen.level(0)
    x=64
    y=28
    w=string.len(s.message)*6
    screen.rect(x-w/2,y,w,10)
    screen.fill()
    screen.level(15)
    screen.rect(x-w/2,y,w,10)
    screen.stroke()
    screen.move(x,y+7)
    screen.text_center(s.message)
  end
  
  screen.update()
end

--
-- utils
--
function round(x)
  return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end

function sign(x)
  if x>0 then
    return 1
  elseif x<0 then
    return-1
  else
    return 0
  end
end

function round_to_nearest(x,yth)
  return x-(x%yth)
end

function max(a)
  local values={}
  
  for k,v in pairs(a) do
    values[#values+1]=v
  end
  table.sort(values) -- automatically sorts lowest to highest
  
  return values[#values]
end

function show_message(message)
  clock.run(function()
    s.message=message
    redraw()
    clock.sleep(0.5)
    s.message=""
    redraw()
  end)
end

function nearest_value(t,number)
  local best_diff=10000
  local closet_index=1
  for i,y in pairs(t) do
    local d=math.abs(number-i)
    if d<best_diff then
      best_diff=d
      closet_index=i
    end
  end
  return closet_index,t[closet_index]
end

function quantile(t,q)
  assert(t~=nil,"No table provided to quantile")
  assert(q>=0 and q<=1,"Quantile must be between 0 and 1")
  table.sort(t)
  local position=#t*q+0.5
  local mod=position%1
  
  if position<1 then
    return t[1]
  elseif position>#t then
    return t[#t]
  elseif mod==0 then
    return t[position]
  else
    return mod*t[math.ceil(position)]+
    (1-mod)*t[math.floor(position)]
  end
end
