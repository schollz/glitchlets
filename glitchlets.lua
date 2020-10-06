
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
    params:add_control(i.."glitch length",i.."glitch length",controlspec.new(0,64,'lin',1,1,'beats'))
    params:set_action(i.."glitch length",update_parameters)
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
    s.v[i].glitch_length=0
    s.v[i].glitch_end=0
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
    softcut.loop_start(i,clock.get_beat_sec()*params:get(i.."sample start"))
    softcut.loop_end(i,clock.get_beat_sec()*params:get(i.."sample start")+clock.get_beat_sec()*params:get(i.."sample length"))
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
  -- TODO
  -- check all parameters for each voice and update
  -- if it has changed
end

function update_amp(val)
  -- toggle recording on with incoming amplitude
  -- toggle recording off with silence
  table.insert(s.amps,val)
  s.update_ui=true
end

function update_loop_length(x)
  
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
  
  draw_waveform()
  
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

function draw_waveform()
  -- show amplitudes
  local l=1
  local r=128
  local w=r-l
  local m=32
  local h=32
  
  local amps={}
  -- truncate amps to the the current biased loop
  for k,v in pairs(s.amps) do
    if k*s.resolution>=s.loop_bias[1] and k*s.resolution<=s.loop_end-s.loop_bias[2] then
      table.insert(amps,v)
    end
  end
  maxval=max(amps)
  nval=#amps
  
  maxw=nval
  if maxw>w then
    maxw=w
  end
  
  -- find active positions
  active_pos={}
  for i=2,6 do
    if s.v[i].midi>0 then
      curpos=(s.v[i].position-s.v[i].loop_bias[1])/(s.loop_end-s.v[i].loop_bias[2]-s.v[i].loop_bias[1])
      table.insert(active_pos,round(curpos*maxw))
      table.insert(active_pos,round(curpos*maxw)+1)
      table.insert(active_pos,round(curpos*maxw)-1)
    end
  end
  
  disp={}
  for i=1,w do
    disp[i]=-1
  end
  if nval<w then
    -- draw from left to right
    for k,v in pairs(amps) do
      disp[k]=(v/maxval)*h
    end
  else
    for i=1,w do
      disp[i]=-2
    end
    for k,v in pairs(amps) do
      i=round(w/nval*k)
      if i>=1 and i<=w then
        if disp[i]==-2 then
          disp[i]=(v/maxval)*h
        else
          disp[i]=(disp[i]+(v/maxval)*h)/2
        end
      end
    end
    for k,v in pairs(disp) do
      if v==-2 then
        if k==1 then
          disp[k]=0
        else
          disp[k]=disp[k-1]
        end
      end
    end
  end
  
  maxval=max(disp)
  for k,v in pairs(disp) do
    if v==-1 then
      break
    end
    bright=false
    for l,u in pairs(active_pos) do
      if k==u then
        bright=true
      end
    end
    if bright then
      screen.level(15)
    else
      screen.level(1)
    end
    screen.move(l+k,m)
    screen.line(l+k,m+(v/maxval)*h)
    screen.line(l+k,m-(v/maxval)*h)
    screen.stroke()
  end
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
  remainder=x%yth
  if remainder==0 then
    return x
  end
  return x+yth-remainder
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
