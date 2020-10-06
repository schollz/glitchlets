
-- glitchlets v0.1.0
-- glitch it
--
--
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
  armed=false,
  mode=0,
  mode_name="",
  shift=false,
  monitor=false,
  message="",
  ready=false,
  current_beat=0,
  current_note=0,
}

-- constants
function init()
  params:add_separator("glitchlets")
  
  for i=1,6 do
    params:add_group("glitchlet "..i,8)
    params:add_option(i.."active",i.."active",{"no","yes"},1)
    params:set_action(i.."active",update_parameters)
    params:add_taper(i.."volume","volume",0,1,0,0.5,"")
    params:set_action(i.."volume",update_parameters)
    params:add_control(i.."reset every",i.."reset every",controlspec.new(0,64,'lin',1,4,'beats'))
    params:set_action(i.."reset every",update_parameters)
    params:add_control(i.."probability",i.."probability",controlspec.new(0,100,'lin',100,1,'%'))
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
    s.v[i].position=0
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
    softcut.loop_end(i,300)
    softcut.loop(i,1)
    
    softcut.fade_time(i,0.2)
    softcut.level_slew_time(i,2)
    softcut.rate_slew_time(i,2)
    
    softcut.buffer(i,1)
    softcut.position(i,0)
    softcut.enable(i,1)
  end
  
  -- initialize timers
  -- initialize timer for updating screen
  timer=metro.init()
  timer.time=0.025
  timer.count=-1
  timer.event=update_main
  timer:start()
  
  -- position poll
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
  
  -- amplitude poll
  p_amp_in=poll.set("amp_in_l")
  p_amp_in.time=0.025
  p_amp_in.callback=update_amp
  p_amp_in:start()
end

--
-- updaters
--
function update_vol(x)
  for i=2,6 do
    if s.v[i].midi>0 then
      softcut.level(i,util.clamp(x*params:get("root_note")/s.v[i].midi,0,1))
    end
  end
end

function update_parameters(x)
  params:write(_path.data..'glitchlets/'.."glitchlets.pset")
end

function update_positions(i,x)
  -- keep track of bounds of recording
  if i==1 and s.recording then
    s.loop_end=x
  end
  s.v[i].last_position=s.v[i].position
  s.v[i].position=x
  if s.v[i].midi>0 then
    s.update_ui=true
  end
end

function update_freq(f)
  -- ignore frequencies below 30 hz
  if s.recording and f>30 and f<1000 then
    current_position=get_position(1)
    if s.freqs[current_position]~=nil then
      s.freqs[current_position]=(s.freqs[current_position]+f)/2
    else
      s.freqs[current_position]=f
    end
    -- print("current_position: "..current_position..", f: "..s.freqs[current_position])
    s.median_frequency=median(s.freqs)
  end
end

function get_position(i)
  return tonumber(string.format("%.3f",round_to_nearest(s.v[i].position,params:get("resolution")/1000)))
end

function update_main()
  if s.update_ui then
    redraw()
  end
  if math.floor(clock.get_beats())~=s.current_beat and params:get("probability")>0 then
    -- randomize notes
    s.current_beat=math.floor(clock.get_beats())
    if math.random()*100<params:get("probability") then
      -- play a random note
      available_notes={}
      median_note=MusicUtil.freq_to_note_num(s.median_frequency)
      -- print("median_note "..median_note)
      -- print("s.median_frequency "..s.median_frequency)
      for k,v in pairs(s.notes) do
        
        table.insert(available_notes,v)
        -- if v<median_note then
        --   table.insert(available_notes,v)
        -- end
      end
      if #available_notes>0 then
        clock.run(function()
          local note=available_notes[math.random(#available_notes)]
          local num_beats=math.random(params:get("min length"),params:get("max length"))
          local played=note_play(note)
          print(played)
          if played then
            print("playing "..note.." for "..num_beats.." beats")
            clock.sync(num_beats)
            note_stop(note)
          end
        end)
      end
    end
  end
  if s.monitor_update then
    s.monitor_update=false
    if s.monitor then
      audio.level_monitor(1)
    else
      audio.level_monitor(0)
    end
  end
  -- check active voices and match their pitch using rate
  for i=2,6 do
    -- skip if not playing
    if s.v[i].midi==0 then goto continue end
    
    -- make sure there is a little bit of recorded material
    if s.loop_end<params:get("min recorded")/1000 then goto continue end
    
    -- make sure its bounded by recorded material
    -- and biased by the current bias
    if s.v[i].started==false or s.loop_end~=s.v[i].loop_end or s.v[i].loop_bias[1]~=s.loop_bias[1] or s.v[i].loop_bias[2]~=s.loop_bias[2] then
      -- print("voice "..i.." updating loop points")
      s.v[i].loop_bias={s.loop_bias[1],s.loop_bias[2]}
      s.v[i].loop_end=s.loop_end
      softcut.loop_end(i,s.loop_end-s.loop_bias[2])
      softcut.loop_start(i,s.loop_bias[1])
    end
    
    -- determine target frequency
    local ref_freq=0
    if params:get("playback reference")==2 then
      ref_freq=s.median_frequency
    elseif params:get("playback reference")==3 then
      -- determine from realtime frequencies
      -- modulate the voice's rate to match upcoming pitch
      -- find the closest pitch
      -- values={}
      -- for j=0,1,0.1 do
      --   next_position=s.v[i].position+j*(s.v[i].position-s.v[i].last_position)
      --   index,f=nearest_value(s.freqs,next_position)
      --   table.insert(values,f)
      --   print(f)
      -- end
      -- ref_freq=median(values)
      -- print("next_position: "..next_position)
      -- print("index: "..index)
      -- print("ref_freq: "..ref_freq)
      index,ref_freq=nearest_value(s.freqs,s.v[i].position+params:get("resolution")/1000*2)
    else
      -- middle c
      ref_freq=261.63
    end
    
    -- initialize the voice playing
    if s.v[i].started==false then
      print("starting "..i)
      s.v[i].started=true
      if s.recording and params:get("live follow")==2 then
        s.v[i].position=util.clamp(s.v[1].position-params:get("min recorded")/1000,s.loop_bias[1],s.loop_end-s.loop_bias[2])
      elseif params:get("notes start at 0")==2 then
        s.v[i].position=s.loop_bias[1]
      else
        s.v[i].position=util.clamp(s.v[i].position,s.loop_bias[1],s.loop_end-s.loop_bias[2])
      end
      softcut.position(i,s.v[i].position)
      softcut.play(i,1)
      update_vol(params:get("notes vol"))
    end
    
    -- update the rate to match correctly modulate upcoming pitch
    if s.v[i].ref_freq~=ref_freq and ref_freq~=nil then
      s.v[i].ref_freq=ref_freq
      -- print("ref_freq: "..ref_freq)
      softcut.rate(i,s.v[i].freq/s.v[i].ref_freq)
    end
    ::continue::
  end
end

function rec_start()
  print("init recording")
  -- reset positions of all current notes
  for i=2,6 do
    softcut.position(i,s.loop_bias[1])
    softcut.level(i,0)
    s.v[i].started=false
  end
  -- initialize recording
  softcut.position(1,0)
  softcut.play(1,1)
  softcut.loop_end(1,300)
  s.freqs={}
  s.amps={}
  s.loop_bias={0,0}
  s.recording=true
  s.loop_end=1
  s.silence_time=0
  -- slowly start recording
  -- ease in recording signal to avoid clicks near loop points
  clock.run(function()
    if params:get("vol pinch")>0 then
      for j=1,10 do
        softcut.rec(1,j*0.1)
        clock.sleep(params:get("vol pinch")/10/1000)
      end
    end
    softcut.rec(1,1)
  end)
end

function rec_stop()
  print("stop recording")
  s.recording=false
  -- slowly stop
  clock.run(function()
    if params:get("vol pinch")>0 then
      for j=1,10 do
        softcut.rec(1,(10-j)*0.1)
        clock.sleep(params:get("vol pinch")/10/1000)
      end
    end
    softcut.rec(1,0)
    softcut.play(1,0)
    softcut.position(1,0)
    s.loop_end=s.v[1].position-(params:get("silence to stop")/1000)
  end)
  if params:get("keep armed")==1 then
    s.armed=false
  end
  if params:get("only play during rec")==2 then
    -- shtudown notes
    for i=2,6 do
      if s.v[i].midi>0 then
        print("voice "..i.." off")
        softcut.level(i,0)
        s.v[i].midi=0
        s.v[i].freq=0
        s.v[i].started=false
      end
    end
  end
end

function update_amp(val)
  -- toggle recording on with incoming amplitude
  -- toggle recording off with silence
  if s.recording then
    table.insert(s.amps,val)
    s.update_ui=true
  end
  if val>params:get("rec thresh")/1000 then
    -- reset silence time
    s.silence_time=0
    if not s.recording and s.armed then
      rec_start()
    end
  elseif s.recording and not s.force_recording then
    -- not above threshold, should add to silence time
    -- to eventually trigger stop recording
    s.silence_time=s.silence_time+params:get("resolution")/1000
    if s.silence_time>params:get("silence to stop")/1000 then
      rec_stop()
    end
  end
end

function update_midi(data)
  msg=midi.to_msg(data)
  if msg.type=='note_on' then
    note_play(msg.note)
  elseif msg.type=='note_off' then
    note_stop(msg.note)
  end
end

--
-- playing/stopping notes
--
function note_play(note)
  -- find first available voice and turn it on
  -- it will be initialized in update_main
  played=false
  if params:get("only play during rec")==2 and not s.recording then
    -- do nothing
  elseif params:get("midi during rec")==1 and (s.recording or s.armed) then
    -- do nothing
  else
    -- try playing note
    for i=2,6 do
      if s.v[i].midi==0 then
        print("voice "..i.." "..note.." on")
        s.v[i].midi=note
        s.v[i].freq=midi_to_hz(note)
        s.v[i].ref_freq=0
        played=true
        break
      end
    end
  end
  return played
end

function note_stop(note)
  -- turn off any voices on that note
  -- print("stopping "..note)
  for i=2,6 do
    if s.v[i].midi==note then
      print("voice "..i.." "..note.." off")
      softcut.level(i,0)
      s.v[i].midi=0
      s.v[i].freq=0
      s.v[i].started=false
    end
  end
end

--
-- input
--

function key(n,z)
  if not s.ready then
    do return end
  end
  if n==1 then
    if z==1 then
      s.shift=true
    else
      s.shift=false
    end
  elseif s.shift and n==2 and z==1 then
    -- toggle monitor
    s.monitor=not s.monitor
    s.monitor_update=true
    if s.monitor then
      show_message("monitor enabled")
    else
      show_message("monitor disabled")
    end
  elseif not s.shift and n==2 and z==1 then
    s.armed=not s.armed
  elseif not s.shift and n==3 and z==1 then
    s.recording=not s.recording
    s.force_recording=s.recording
    if s.recording then
      rec_start()
    else
      rec_stop()
    end
  end
  s.update_ui=true
end

function enc(n,d)
  if s.shift and n==1 then
    params:set("notes vol",util.clamp(params:get("notes vol")+d/100,0,10))
  elseif n==1 then
    if s.mode==0 then
      params:write(_path.data..'glitchlets/'.."glitchlets_temp.pset")
    end
    s.mode=util.clamp(s.mode+sign(d),0,4)
    if s.mode==0 then
      s.mode_name=""
      params:read(_path.data..'glitchlets/'.."glitchlets_temp.pset")
    elseif s.mode==1 then
      s.mode_name="sampler"
      params:set("live follow",1)
      params:set("keep armed",1)
      params:set("playback reference",1)
      params:set("only play during rec",1)
      params:set("notes start at 0",2)
      params:set("midi during rec",1)
      s.armed=true
    elseif s.mode==2 then
      s.mode_name="follower"
      params:set("live follow",2)
      params:set("keep armed",2)
      params:set("silence to stop",200)
      params:set("playback reference",3)
      params:set("only play during rec",2)
      params:set("notes start at 0",1)
      params:set("midi during rec",2)
      s.armed=true
    end
  elseif n==2 then
    s.loop_bias[1]=util.clamp(s.loop_bias[1]+d/100,0,s.loop_end-s.loop_bias[2])
  elseif n==3 then
    s.loop_bias[2]=util.clamp(s.loop_bias[2]-d/100,s.loop_bias[1],s.loop_end)
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
  
  if s.recording then
    screen.level(15)
    screen.rect(108-shift,1+shift,20,10)
    screen.stroke()
    screen.move(111-shift,8+shift)
    screen.text("REC")
  elseif s.armed then
    screen.level(1)
    screen.rect(108-shift,1+shift,20,10)
    screen.stroke()
    screen.move(111-shift,8+shift)
    screen.text("RDY")
  end
  
  screen.level(15)
  if #s.amps==0 then
    screen.move(64,32-8)
    screen.text_center("play instruments")
    screen.move(64,32)
    screen.text_center("while")
    screen.move(64,32+8)
    screen.text_center("instruments play")
  else
    draw_waveform()
  end
  
  screen.move(3+shift,60-shift)
  screen.level(15)
  screen.text(s.mode_name)
  
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
    if k*params:get("resolution")/1000>=s.loop_bias[1] and k*params:get("resolution")/1000<=s.loop_end-s.loop_bias[2] then
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
-- harmonizer
--
function build_scale()
  s.notes=MusicUtil.generate_scale_of_length(params:get("root_note"),params:get("scale_mode"),20)
  local num_to_add=20-#s.notes
  for i=1,num_to_add do
    table.insert(s.notes,s.notes[20-num_to_add])
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

function midi_to_hz(note)
  return (440/32)*(2^((note-9)/12))
end

function max(a)
  local values={}
  
  for k,v in pairs(a) do
    values[#values+1]=v
  end
  table.sort(values) -- automatically sorts lowest to highest
  
  return values[#values]
end

-- Get the median of a table.
-- http://lua-users.org/wiki/SimpleStats
function median(t)
  local temp={}
  
  -- deep copy table so that when we sort it, the original is unchanged
  -- also weed out any non numbers
  for k,v in pairs(t) do
    if type(v)=='number' then
      table.insert(temp,v)
    end
  end
  
  table.sort(temp)
  
  -- If we have an even number of table elements or odd.
  if math.fmod(#temp,2)==0 then
    -- return mean value of middle two elements
    return (temp[#temp/2]+temp[(#temp/2)+1])/2
  else
    -- return middle element
    return temp[math.ceil(#temp/2)]
  end
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
