-- glitchlets v0.1.0
-- lets glitch
-- with
-- glitchlets
--
-- llllllll.co/t/glitchlets
--
--    ▼ instructions below ▼
--
-- set tempo in clock -> tempo
-- before loading
-- hold K1 to turn off glitches
-- K2 manually glitches
-- K3 or K1+K3 switch glitchlet
-- E1 switchs parameters
-- E2/E3 modulate parameters
-- K1+K2 randomizes everything

engine.name='Warb'

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
  current_beat=0,
  current_note=0,
  i=2,
  resolution=clock.get_beat_sec()/16,
  sixteenth_beat=clock.get_beat_sec()/16*1000,
  loop_time=0,
  last_k=0,
  param_mode=0,
  wobbles={1/8,1/4,1/2,1,2},
  endhzs={10,20,30,40,50,60},
  hzs={90,100,110,120,130,80},
  live_glitch_voice=0,
}

-- constants
function init()
  audio.level_eng_cut(0)
  audio.level_adc_cut(1)
  audio.level_tape_cut(1)
  
  print(s.sixteenth_beat)
  params:add_separator("glitchlets")
  params:add_control("loop length","loop length",controlspec.new(0,64,'lin',1,8,'beats'))
  params:set_action("loop length",update_loop_length_and_update)
  params:add{type="control",id="glitch volume",name="glitch volume",controlspec=controlspec.new(0,1,'lin',0,0.5,'')}
  params:set_action("glitch volume",update_parameters)
  params:add{type="control",id="warb volume",name="warb volume",controlspec=controlspec.new(0,1,'lin',0,0.25,''),
  action=function(x) engine.amp(x) end}
  params:set_action("warb volume",update_parameters)
  params:read(_path.data..'glitchlets/'.."glitchlets.pset")
  update_loop_length(params:get("loop length"))

  for i=2,6 do
    params:add_group("glitchlet "..i-1,10)
    params:add_option(i.."active","active",{"no","yes"},1)
    params:add_option(i.."randomize","randomize",{"no","yes"},1)
    params:add_option(i.."gate","gate",{"off","on"},2)
    params:add_taper(i.."volume","volume",0,1,1,.1,"")
    params:add_taper(i.."pan","pan",-1,1,0,.1,"")
    params:add_control(i.."glitch probability","glitch probability",controlspec.new(0,99,'lin',1,99,'%'))
    params:add_control(i.."warb probability","warb probability",controlspec.new(0,99,'lin',1,99,'%'))
    params:add_control(i.."sample start","sample start",controlspec.new(0,s.loop_end*1000,'lin',s.sixteenth_beat,s.loop_end*i/8,'ms'))
    params:add_control(i.."sample length","sample length",controlspec.new(0,s.loop_end*1000,'lin',s.sixteenth_beat,0,'ms'))
    params:add_control(i.."glitches","glitches",controlspec.new(0,64,'lin',1,i+2,'x'))
  end
  
  for i=1,6 do
    s.v[i]={}
    s.v[i].active=0
    s.v[i].playing=false
    s.v[i].loop_reset=true
    s.v[i].position=0
    s.v[i].sample_start=0
    s.v[i].sample_length=0
    s.v[i].sample_end=0
    s.v[i].glitch_num=0
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
    softcut.pre_filter_lp(i,1)
    softcut.post_filter_lp(i,1)
    softcut.pre_filter_fc(i,8000)
    softcut.post_filter_fc(i,8000)
    
    softcut.fade_time(i,0.2)
    softcut.level_slew_time(i,0)
    softcut.rate_slew_time(i,0)
    softcut.phase_quant(i,s.resolution)
  end
  -- have to do this again.... :(
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
  
  if clock.get_beat_sec()/16*1000~=s.sixteenth_beat or s.loop_end~=clock.get_beat_sec()*params:get("loop length") then 
    -- tempo has been changed, do a reset
    print("updating bar")
    s.sixteenth_beat= clock.get_beat_sec()/16*1000
    update_loop_length(params:get("loop length"))
  end
  -- activate if ready
  for i=2,6 do
    if s.shift then goto continue end
    if params:get(i.."active")==1 then goto continue end
    if params:get(i.."glitches")==0 then goto continue end
    if params:get(i.."sample length")==0 then goto continue end
    if s.v[i].playing==true then goto continue end
    if not s.v[i].loop_reset then goto continue end
    
    s.v[i].sample_start=params:get(i.."sample start")/1000
    s.v[i].sample_length=params:get(i.."sample length")/1000
    s.v[i].sample_end=s.v[i].sample_start+s.v[i].sample_length
    local ready=(s.v[i].sample_end-s.v[1].position)<2*s.sixteenth_beat/1000 and (s.v[i].sample_end-s.v[1].position)>0
    if ready==false then goto continue end
    
    local j=i
    clock.run(function()
      print("attempting glitch...")
      local glitched=false
      if math.random()*100<=params:get(j.."warb probability") and params:get("warb volume")*params:get(j.."volume")>0 then
        glitched=true
        glitch_engine(j,s.v[i].sample_length)
      end
      if math.random()*100<params:get(j.."glitch probability") and params:get(j.."volume")*params:get("glitch volume")>0 then
        glitched=true
        glitch_softcut(j,s.v[i].sample_start,s.v[i].sample_end)
      end
      if glitched then
        print("sleeping for "..s.v[j].sample_length*(params:get(j.."glitches")))
        clock.sync(1/16)
        clock.sleep(s.v[j].sample_length*(params:get(j.."glitches")))
        glitch_stop(j)
      end
    end)
    ::continue::
  end
end

function glitch_stop(j)
  print("stopped glitch")
  softcut.level(j,0)
  softcut.rate_slew_time(j,0)
  softcut.rate(j,1)
  audio.level_monitor(1)
  s.v[j].playing=false
  if params:get(j.."randomize")==2 then
    params:set(j.."sample start",util.clamp(math.random()*s.loop_end*1000,s.sixteenth_beat,s.loop_end*1000-params:get(j.."sample length")))
    s.update_ui=true
  end
end

function glitch_engine(j,length)
  if params:get(j.."gate")==2 then
    audio.level_monitor(0)
  end
  s.v[j].playing=true
  s.v[j].loop_reset=false
  local total_length=length*params:get(j.."glitches")
  engine.attack(total_length*1/10)
  engine.sustainTime(total_length)
  engine.release(total_length)
  engine.amp(params:get("warb volume")*params:get(j.."volume"))
  engine.wobble(s.wobbles[math.random(#s.wobbles)])
  engine.endfreq(s.endhzs[math.random(#s.endhzs)])
  engine.hz(s.hzs[math.random(#s.hzs)])
end

function glitch_softcut(j,start,e)
  if params:get(j.."gate")==2 then
    audio.level_monitor(0)
  end
  s.v[j].playing=true
  s.v[j].loop_reset=false
  softcut.loop_start(j,start)
  softcut.loop_end(j,e)
  softcut.position(j,start)
  softcut.pan(j,params:get(j.."pan"))
  softcut.level(j,params:get(j.."volume")*params:get("glitch volume"))
  local rrand=math.random(5)
  if rrand==1 then
    softcut.rate(j,1)
  elseif rrand==2 then
    softcut.rate(j,1.5)
  elseif rrand==3 then
    softcut.rate(j,-1)
    softcut.rate_slew_time(j,(e-start)*10)
    softcut.rate(j,2)
  elseif rrand==4 then
    softcut.rate(j,2)
    softcut.rate_slew_time(j,(e-start)*20)
    softcut.rate(j,-0.125)
  elseif rrand==5 then
    softcut.rate(j,1)
    softcut.rate_slew_time(j,(e-start)*20)
    softcut.rate(j,4)
  end
  
end

function update_amp(val)
  k=round_to_nearest(s.v[1].position,s.resolution)/s.resolution
  if k~=s.last_k or s.amps[k]==nil then
    if k<s.last_k then
      print("reseting loop "..s.v[1].position.." loop end="..s.loop_end)
      for i=2,6 do
        s.v[i].loop_reset=true
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
  for i=1,(clock.get_beat_sec()*x)/s.resolution do
    table.insert(s.amps,0)
  end
  s.loop_end=clock.get_beat_sec()*x
  print("final: "..s.loop_end)
  print("final: "..s.loop_end/s.resolution)
  softcut.loop_start(1,0)
  softcut.loop_end(1,clock.get_beat_sec()*x)
end

function update_loop_length_and_update(x)
  update_loop_length(x)
  params:write(_path.data..'glitchlets/'.."glitchlets.pset")
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
  elseif n==2 and s.shift==true then 
    show_message("randomzing!")
    for i=2,6 do
      params:set(i.."active",math.random(2))
      params:set(i.."randomize",math.random(2))
      params:set(i.."gate",math.random(2))
      params:set(i.."pan",math.random()*2-1)
      params:set(i.."glitch probability",math.random()*99)
      params:set(i.."warb probability",math.random()*99)
      params:set(i.."sample length",s.sixteenth_beat*math.random(8))
      params:set(i.."sample start",util.clamp(s.loop_end*1000*math.random(),0,s.loop_end*1000-s.sixteenth_beat*9))
      params:set(i.."glitches",math.random(8))
    end
  elseif n==2  then
    available=0
    for i=2,6 do
      if s.v[i].playing==false then 
        available=i 
        break
      end
    end
    if available > 0 and z==1 then
      glitch_softcut(available,s.v[1].position-s.sixteenth_beat/1000*4,s.v[1].position)
      glitch_engine(available,s.sixteenth_beat/1000*4)
    elseif z==0 then 
      for i=2,6 do 
        if s.v[i].playing==true then 
          glitch_stop(i)
        end
      end
    end
  elseif n>1 and z==1 then
     -- this code looks weird because i didn't want to rewrite it
    local adj=1
    if n==2 or s.shift then
      adj=-1
    end
    local foo=s.i+adj
    if foo<2 then
      foo=6
    elseif foo>6 then
      foo=2
    end
    s.i=foo
  end
  s.update_ui=true
end

function enc(n,d)
  if s.shift and n==1 then
  elseif n==1 then
    s.param_mode=util.clamp(s.param_mode+sign(d),0,3)
  elseif n==2 and s.param_mode==0 then
    if params:get(s.i.."active")==1 then
      print("activating")
      params:set(s.i.."active",2)
    end
    params:set(s.i.."sample start",params:get(s.i.."sample start")+sign(d)*s.sixteenth_beat)
    if params:get(s.i.."sample length")==0 then
      params:set(s.i.."sample length",s.sixteenth_beat)
    end
    local i=s.i
    s.v[i].sample_start=params:get(i.."sample start")/1000
    s.v[i].sample_length=params:get(i.."sample length")/1000
    s.v[i].sample_end=s.v[i].sample_start+s.v[i].sample_length
  elseif n==3 and s.param_mode==0 then
    if params:get(s.i.."active")==1 then
      print("activating")
      params:set(s.i.."active",2)
    end
    params:set(s.i.."sample length",params:get(s.i.."sample length")+sign(d)*s.sixteenth_beat)
    local i=s.i
    s.v[i].sample_start=params:get(i.."sample start")/1000
    s.v[i].sample_length=params:get(i.."sample length")/1000
    s.v[i].sample_end=s.v[i].sample_start+s.v[i].sample_length
  elseif n==2 and s.param_mode==1 then
    params:set(s.i.."glitches",util.clamp(params:get(s.i.."glitches")+sign(d),0,12))
  elseif n==3 and s.param_mode==1 then
    params:set(s.i.."volume",util.clamp(params:get(s.i.."volume")+d/100,0,1))
  elseif n==2 and s.param_mode==2 then
    params:set(s.i.."glitch probability",util.clamp(params:get(s.i.."glitch probability")+d,0,100))
  elseif n==3 and s.param_mode==2 then
    params:set(s.i.."warb probability",util.clamp(params:get(s.i.."warb probability")+d,0,100))
  elseif n==2 and s.param_mode==3 then
    params:set(s.i.."randomize",util.clamp(params:get(s.i.."randomize")+sign(d),1,2))
  elseif n==3 and s.param_mode==3 then
    params:set(s.i.."gate",util.clamp(params:get(s.i.."gate")+sign(d),1,2))
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
  if s.param_mode==0 then 
    screen.level(15)
  else
    screen.level(1)
  end
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
  screen.text(string.format("%2.1famp",params:get(s.i.."volume")))

  if s.param_mode==2 then
    screen.level(15)
  else
    screen.level(1)
  end
  screen.move(x+54,y)
  screen.text(params:get(s.i.."glitch probability").."%")
  screen.move(x+74,y)
  screen.text(params:get(s.i.."warb probability").."%")
  screen.move(x+94,y)
  if s.param_mode==3 then
    screen.level(15)
  else
    screen.level(1)
  end
  local text =""
  if params:get(s.i.."randomize")==2 then 
    text=text.."r "
  end
  if params:get(s.i.."gate")==2 then 
    text=text.."g"
  end
  screen.text(text)

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
  nval=#s.amps
  
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
      if s.v[i].active and time_per_x*x>=params:get(i.."sample start")/1000 and time_per_x*x<=(params:get(i.."sample start")+params:get(i.."sample length"))/1000 and params:get(i.."sample length")>0 then
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
        screen.level(15)
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

