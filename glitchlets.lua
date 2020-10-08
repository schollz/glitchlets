-- glitchlets v0.1.0
-- lets glitch
-- with
-- glitchlets
--
-- llllllll.co/t/glitchlets
--
--    ▼ instructions below ▼
--

engine.name = 'Warb'

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
  resolution=clock.get_beat_sec()/32,
  sixteenth_beat=clock.get_beat_sec()/32*1000,
  loop_time=0,
  last_k=0,
  param_mode=0,
  wobbles={1/2,2,1,1/3,1/4},
}

-- constants
function init()
  print(s.sixteenth_beat)
  params:add_separator("glitchlets")
  params:add_control("loop length","loop length",controlspec.new(0,64,'lin',1,8,'beats'))
  params:set_action("loop length",update_loop_length_and_update)
    cs_AMP = controlspec.new(0,1,'lin',0,0.5,'')
params:add{type="control",id="glitch amp",name="glitch amp",controlspec=cs_AMP}
params:add{type="control",id="engine amp",name="engine amp",controlspec=cs_AMP,
    action=function(x) engine.amp(x) end}

  for i=2,6 do
    params:add_group("glitchlet "..i-1,8)
    params:add_option(i.."active","active",{"no","yes"},1)
    params:set_action(i.."active",update_parameters)
    params:add_taper(i.."volume","volume",0,1,1,.1,"")
    params:set_action(i.."volume",update_parameters)
    params:add_control(i.."reset every","reset every",controlspec.new(0,64,'lin',1,4,'beats'))
    params:set_action(i.."reset every",update_parameters)
    params:add_control(i.."glitch probability","glitch probability",controlspec.new(0,100,'lin',1,100,'%'))
    params:set_action(i.."glitch probability",update_parameters)
    params:add_control(i.."warb probability","warb probability",controlspec.new(0,100,'lin',1,100,'%'))
    params:set_action(i.."warb probability",update_parameters)
    params:add_control(i.."sample start","sample start",controlspec.new(0,6400,'lin',s.sixteenth_beat,0,'ms'))
    params:set_action(i.."sample start",update_parameters)
    params:add_control(i.."sample length","sample length",controlspec.new(0,6400,'lin',s.sixteenth_beat,s.sixteenth_beat*2,'ms'))
    params:set_action(i.."sample length",update_parameters)
    params:add_control(i.."glitch start","glitch start",controlspec.new(0,6400,'lin',s.sixteenth_beat,0,'ms'))
    params:set_action(i.."glitch start",update_parameters)
    params:add_control(i.."glitches","glitches",controlspec.new(0,64,'lin',1,4,'x'))
    params:set_action(i.."glitches",update_parameters)
  end
  
  -- params:read(_path.data..'glitchlets/'.."glitchlets.pset")
  
  for i=1,6 do
    s.v[i]={}
    s.v[i].active=0
    s.v[i].playing=false
    s.v[i].loop_reset=false
    s.v[i].volume=0
    s.v[i].position=0
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
    softcut.buffer(i,1)
    softcut.position(i,0)
    softcut.enable(i,1)
    if i==1 then
      -- voice 1 records into buffer, but does not play
      softcut.level(i,0)
      softcut.level_input_cut(1,i,1)
      softcut.level_input_cut(2,i,1)
      softcut.rec_level(i,1)
      softcut.pre_level(i,0)
    else
      softcut.level(i,0)
      softcut.level_input_cut(1,i,0)
      softcut.level_input_cut(2,i,0)
    end
    softcut.play(i,1)
    softcut.rec(i,0)
    softcut.pan(i,0)
    softcut.rate(i,1)
    softcut.loop_start(i,0)
    softcut.loop_end(i,30)
    softcut.loop(i,1)
    
    softcut.fade_time(i,0.2)
    softcut.level_slew_time(i,0)
    softcut.rate_slew_time(i,0)
    softcut.phase_quant(i,s.resolution)
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
  
  softcut.play(1,1)
  softcut.rec(1,1)
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
  if math.floor(clock.get_beats())%params:get("loop length")==0 and s.loop_time~=0 then
    -- reset amplitude time
    s.loop_time=0
  end
  -- TODO
  -- check all parameters for each voice and update
  -- if it has changed
  if s.update_parameters then
    for i=2,6 do
      if s.v[i].sample_start~=params:get(i.."sample start")/1000 or s.v[i].sample_length~=params:get(i.."sample length")/1000 then
        s.v[i].sample_start=params:get(i.."sample start")/1000
        s.v[i].sample_length=params:get(i.."sample length")/1000
        s.v[i].sample_end=s.v[i].sample_start+s.v[i].sample_length
      end
      if s.v[i].volume~=params:get(i.."volume") then
        s.v[i].volume=params:get(i.."volume")
      end
      if s.v[i].glitches~=params:get(i.."glitches") then
        s.v[i].glitches=params:get(i.."glitches")
      end
      if s.v[i].active~=(params:get(i.."active")==2) then
        s.v[i].active=(params:get(i.."active")==2)
      end
    end
  end
  -- activate if ready
  for i=2,6 do
    if s.shift then goto continue end
    if not s.v[i].active then goto continue end
    if s.v[i].glitches==0 then goto continue end
    if s.v[i].sample_length==0 then goto continue end
    if s.v[i].playing==true then goto continue end
    if not s.v[i].loop_reset then goto continue end
    active1=(s.v[1].position<s.loop_end and math.abs(s.v[1].position-s.v[i].sample_start)<s.sixteenth_beat/1000)
    active2=(s.v[1].position>=s.loop_end and math.abs(s.v[1].position-s.loop_end-s.v[i].sample_start)<s.sixteenth_beat/1000)
    if (active1==false and active2==false) then goto continue end
    if math.random()*100<=params:get(i.."warb probability") then 
	    engine.amp(params:get("engine amp")*params:get(i.."volume"))
	    engine.wobble(s.wobbles[math.random(#s.wobbles)])
	    engine.hz(440)
    end
    if math.random()*100>params:get(i.."glitch probability") then goto continue end
    
    s.v[i].playing=true
    s.v[i].loop_reset=false
    local j=i
    clock.run(function()
      clock.sleep(s.v[j].sample_length)
      print("glitching "..j)
      print("stopping in "..s.v[j].sample_length*s.v[j].glitches)
      print("sample_length "..s.v[j].sample_length)
      if active1 then
        softcut.position(i,s.v[i].sample_start+s.loop_end)
        softcut.loop_start(i,s.v[i].sample_start+s.loop_end)
        softcut.loop_end(i,s.v[i].sample_end+s.loop_end)
      else
        softcut.position(i,s.v[i].sample_start)
        softcut.loop_start(i,s.v[i].sample_start)
        softcut.loop_end(i,s.v[i].sample_end)
      end
      softcut.level(j,s.v[j].volume*params:get("glitch level"))
      audio.level_monitor(0)
      -- for k=1,10 do
      --   softcut.pre_filter_fc(j,15000-1500*k)
      --   softcut.post_filter_fc(j,15000-1500*k)
      --   clock.sleep(s.v[j].sample_length*(s.v[j].glitches+3)/20)
      -- end
      -- for k=1,10 do
      --   softcut.pre_filter_fc(j,1500*k)
      --   softcut.post_filter_fc(j,1500*k)
      --   clock.sleep(s.v[j].sample_length*(s.v[j].glitches+3)/20)
      -- end
      local rrand=math.random()
      if rrand<0.33 then
        softcut.rate(j,1.5)
      elseif rrand<0.66 then
        softcut.rate(j,2)
      else
        softcut.rate(j,1)
      end
      clock.sleep(s.v[j].sample_length*(s.v[j].glitches+1))
      print("stopping "..j)
      softcut.level(j,0)
      audio.level_monitor(1)
      s.v[j].playing=false
    end)
    ::continue::
  end
end

function update_amp(val)
  k=round_to_nearest(s.v[1].position,s.resolution)/s.resolution
  if k~=s.last_k or s.amps[k]==nil then
    if k<s.last_k or (s.last_k<s.loop_end/s.resolution and k>=s.loop_end/s.resolution) then
      print("reseting loop "..s.v[1].position.." loop end="..s.loop_end)
      for i=2,6 do
        s.v[i].loop_reset=true
      end
      if math.random()<0.5 then
        print("high pass")
        softcut.pre_filter_hp (1,1)
        softcut.pre_filter_fc(1,12000)
      else
        print("low pass")
        softcut.pre_filter_lp (1,1)
        softcut.pre_filter_fc(1,600)
      end
    end
    s.amps[k]=val
    s.update_ui=true
  else
    s.amps[k]=(val+s.amps[k])/2
  end
  s.last_k=k
end

function update_loop_length(x)
  -- rebuild table
  s.amps={}
  for i=1,(clock.get_beat_sec()*x*2)/s.resolution do
    table.insert(s.amps,0)
  end
  s.loop_end=clock.get_beat_sec()*x
  softcut.loop_end(1,clock.get_beat_sec()*x*2)
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
  elseif n>1 and z==1 then
    local adj=1
    if n==2 then
      adj=-1
    end
   local foo = s.param_mode+adj
   if foo < 0 then 
	   foo = 2
   elseif foo > 2 then 
	   foo = 0
   end
   s.param_mode=foo
  end
  s.update_ui=true
end

function enc(n,d)
  if s.shift and n==1 then
  elseif n==1 then
    s.i=util.clamp(s.i+sign(d),2,6)
  elseif n==2 and s.param_mode==0 then
    if params:get(s.i.."active")==1 then
      print("activating")
      params:set(s.i.."active",2)
    end
    params:set(s.i.."sample start",params:get(s.i.."sample start")+sign(d)*s.sixteenth_beat)
    if params:get(s.i.."sample length")==0 then
      params:set(s.i.."sample length",s.sixteenth_beat)
    end
  elseif n==3 and s.param_mode==0 then
    if params:get(s.i.."active")==1 then
      print("activating")
      params:set(s.i.."active",2)
    end
    params:set(s.i.."sample length",params:get(s.i.."sample length")+sign(d)*s.sixteenth_beat)
  elseif n==2 and s.param_mode==1 then
    params:set(s.i.."glitches",util.clamp(params:get(s.i.."glitches")+sign(d),0,12))
  elseif n==3 and s.param_mode==1 then
    params:set(s.i.."volume",util.clamp(params:get(s.i.."volume")+d/100,0,1))
  elseif n==2 and s.param_mode==2 then
    params:set(s.i.."glitch probability",util.clamp(params:get(s.i.."glitch probability")+d,0,100))
  elseif n==3 and s.param_mode==2 then
    params:set(s.i.."warb probability",util.clamp(params:get(s.i.."warb probability")+d,0,100))
  end
  s.update_ui=true
end

--
-- screen
--
function redraw()
  s.update_ui=false
  screen.clear()
  
  shift_amount=0
  if s.shift then
    shift_amount=5
  end
  
  -- show glitchlet info
  x=4+shift_amount
  y=8+shift_amount
  screen.move(x,y)
  screen.text(s.i-1)
  screen.move(x,y)
  screen.rect(x-3,y-7,10,10)
  screen.stroke()
  if s.param_mode==1 then
    screen.level(15)
  else
    screen.level(1)
  end
  screen.move(x+10,y)
  screen.text("x"..params:get(s.i.."glitches"))
  screen.move(x+24,y)
  screen.text(params:get(s.i.."volume").."amp")
  if s.param_mode==2 then
    screen.level(15)
  else
    screen.level(1)
  end
  screen.move(x+38,y)
  screen.text(params:get(s.i.."glitch probability").."%")
  screen.move(x+52,y)
  screen.text(params:get(s.i.."warb probability").."%")
  
  -- draw waveform
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
  local h=48
  local m=57
  
  maxval=max(s.amps)
  nval=#s.amps/2
  
  maxw=nval
  if maxw>w then
    maxw=w
  end
  
  disp={}
  for k,v in pairs(s.amps) do
    if k>nval then
      k=k-nval
    end
    x=l+round((k-1)/nval*w)
    if disp[x]==nil then
      disp[x]={}
    end
    table.insert(disp[x],v)
  end
  for x,v in pairs(disp) do
    disp[x]=average(v)
  end
  maxval=max(disp)
  
  time_per_x=s.loop_end/w
  dots={false,false,false,false,false,false}
  for x,v in pairs(disp) do
    screen.level(1)
    for i=2,6 do
      if s.v[i].active and time_per_x*x>=s.v[i].sample_start and time_per_x*x<=s.v[i].sample_end then
        if dots[i]==false then
          dots[i]=true
          screen.level(1)
          if s.v[i].playing then
            screen.level(15)
          end
          screen.move(x,64)
          screen.text(i-1)
          screen.fill()
        end
        if s.param_mode==0 then
          screen.level(15)
        end
      end
    end
    screen.move(x,m)
    screen.line(x,m-(v/maxval)*h)
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

function average(t)
  local sum=0
  local count=0
  
  for k,v in pairs(t) do
    if type(v)=='number' then
      sum=sum+v
      count=count+1
    end
  end
  
  return (sum/count)
end

