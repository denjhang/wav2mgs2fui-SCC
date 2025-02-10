require("..tools")
require("..debug")

local header = {0x46,0x49,0x4E,0x53,0xDF,0x00,0x12,0x00,0x4D,0x41,0x11,0x02,0x08,0x00,0x00,0xFF,0xFF,0xFF,0x00,0x01,0x00,0x01}
local mider = {0x01, 0xff, 0xff, 0xff, 0x0, 0x41, 0x0, 0x01}
local ender = {0xff}
local default_step={}  --默认步长
local compress_step=0 --是否压缩步长
--local str1 = "V13O2BV15O4CV14C+V13D%3V11D+V14F%3V15GV10G+V9F+%3O6F+V10FV11F%3V12FFV10F%3"
--local str ="9 V11F+G%3V9GV11GV13G%3V12GV9GV6G%3V4O7C+V3C%3V4CCV5O6F+%3V7C+V6D"
--local str="0 V13D%3V11D+V13D%3V11D"
--local str1 ="9 V12G+%3V13G+G+G+%3V12G+G+V10G%3V8FV9F+%3V6EV11EV10E%3V12D+D+V7E%3"



function parse_mml_line(channel,line)
    if line==nil or line=="" then
        return nil, nil
    end
    local vol = {}
    local arp = {}
    local vpos = 1
    local current_volume = 5
    local current_pitch = 4
    local current_node = 0
    local note_volume = 0
    local current_step=0
    local note_to_pitch = {C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11}
    local strlen = string.len(line)
    local k = 1
   -- print ("line="..line)

    while k <= strlen do
        local v = string.sub(line, k, k)
        --print("v="..v.." "..k)
        if k == 0 then
        else
            if v == " " or v=="\n" or v=="\r" or v=="\t" then
            elseif v == "V" or v == "v" then
                current_volume = string.match(line, "(%d+)", k)
               -- print("current_volume="..current_volume)
                k = k + string.len(current_volume)
            elseif v == "O" or v == "o" then
                current_pitch = string.match(line, "(%d+)", k)
               -- print("current_pitch="..current_pitch)
                k = k + string.len(current_pitch)
            elseif v=="@" then
                --9 @15Q0L%2
                --4 @00L%2
                local skip,cur=string.match(line,"(%d+.*L%%)(%d+)")
                if cur~=nil then
                    default_step[channel]=math.floor(cur)-compress_step
                    if default_step[channel]<=0 then
                        default_step[channel]=1
                    end
                   -- print("default_step1="..default_step[channel])   
                    k=k+string.len(cur)+string.len(skip)
                end    
            elseif v == "R" then
                --current_volume=0
                note_volume = 0
                current_node = 0
                local cnt = string.match(line, "(%%%d+)", k)
               -- print("cnt="..cnt)
                if cnt ~= nil then
                    k = k + string.len(cnt)
                    cnt = string.sub(cnt, 2)
                    for i = 1, math.floor(cnt) do
                        table.insert(vol, note_volume)
                        table.insert(arp, current_node)
                    end
                else
                    print("R error!")
                end
                
            else
                local node = string.match(line, "([A-Ga-gRr][+-]?)", k)
                if node ~= nil then
                    --print ("node="..node)
                    --print("k1="..k.." "..strlen)    
                    local node2 = string.sub(node, 1, 1)
                    if node2 ~= nil and note_to_pitch[node2] ~= nil then
                        current_node = note_to_pitch[node2]
                        if string.len(node) > 1 then
                            local flag = string.sub(node, 2, 2)
                            if flag == "+" then
                                current_node = current_node + 1
                            elseif flag == "-" then
                                current_node = current_node - 1
                            end
                            k = k + 1
                        end
                        local pitch = 12 * (current_pitch - 4)
                        current_node = current_node + pitch
                        note_volume = current_volume
                        --print("node="..current_node)

                        current_step=0
                        if string.sub(line, k+1, k+1) == "%" then
                            --print("in step")
                            local cur = string.match(line, "(%d+)", k)
                            k = k + string.len(cur)+1
                            current_step = math.floor(cur)
                        end
                        --k = k + string.len(node)-1
                        --print("current_volume=",note_volume)
                        --print("default_step="..default_step[channel])   
                        --print("current_step="..current_step)   
                        local step=default_step[channel]
                        if current_step>0 then
                            step=current_step+1
                        end
                        for i=1,step do
                            table.insert(vol, note_volume)
                            table.insert(arp, current_node)
                        end
                        current_step=0
                       -- print("k2="..k.." "..strlen)
                    else
                        print("error!!")
                    end
                else
                    --print ("node="..string.sub(line, k))
                    print("error2!!")
                end
            end
        end
        k = k + 1
       -- print("next="..string.sub(line,k))        
    end
 
    --print("k="..k.." "..strlen)
    return vol, arp
end

function fileWriteData(file, data, offset)
    if file then
        file:seek("set", offset)
        for k, v in ipairs(data) do
            if file:write(string.char(v)) == nil then
                break
            end
        end
    end
end


--[[获取命令行参数,并解析输出目录]]
local argCount = #arg

local input = "..\\t1.txt"
local output=".\\fui"
if argCount >= 2 then    
   input=arg[1]
   if arg[2]~=nil then
      output=arg[2].."\\"
      output = string.gsub(output, "\\", "\\\\")
      output = string.gsub(output, "[/\\]*$", "")      
      if os.execute("cd " .. "\"" .. output .. "\" >nul 2>nul") ~= 0 then
         os.execute("mkdir "..output)
      end
      output=output.."\\"
   end

   --[[
   if arg[3]~=nil then      
      compress_step=string.match(arg[3],"-r(%d+)")
      if compress_step~=nil then
         compress_step=math.floor(compress_step)
         if compress_step<0 or compress_step>9 then
            compress_step=0
         end
      else
         compress_step=0
      end
   end
   ]]

else
    local info=io.pathinfo(arg[0])
    print(info.filename.."  input.txt output_dir")
    --print("-r[0~9] compress setp to 0~9,default is 0")
    return
end

--[[打开输入文件并读入内存]]
local infile = io.open(input, "r")
local content
local channel = {}
if infile == nil then
    return
end
content = infile:read("*all")
infile:close()

--print(content)
content = string.trim(content)
content=string.gsub(content,"\n\n","\n") --删除空行
content=string.gsub(content,"^\n","") --删除开头空行    
content=string.gsub(content,"^\r","") --删除开头空行    
content=string.gsub(content,"^\t","") --删除开头空行        
content=string.gsub(content,"^\r\n","") --删除开头空行    
list = string.split2(content, "\n", " ", false)
--dump(list)


--[[初始化通道数组]]
local off = 1
for k, v in ipairs(list) do
    channel[v[1]] = {vol = {}, arp = {}}
    default_step[v[1]]=2-compress_step
    if default_step[v[1]]<=0 then
        default_step[v[1]]=1
    end
    --print("step="..default_step[v[1]])
end



--[[解析拆分原始数据到通道数组]]
for k, v in ipairs(list) do
    --dump(v,k)
    local vol, arp = parse_mml_line(v[1],v[2])
    if vol == nil or arp == nil then   
    else
      table.insertTo(channel[v[1]].vol, vol, #channel[v[1]].vol + 1)
      table.insertTo(channel[v[1]].arp, arp, #channel[v[1]].arp + 1)
    end
end
--dump(channel["9"].vol,"channel")
--bp.bp()

--[[将解析后的通道数据分别写入txt文件和缓存数组
txt按照原始格式,每个类型最多255个数据,每个数据占一行,数据间用空格隔开
缓存数组按照fui格式,每个通道一个文件,每个文件包含header,vol,mider,arp,ender
fui每通道最大数据量只有255字节,所以先将数据按照255个数据分割,然后存入临时数组备用,
最后将临时数组写入fui文件
]]  
local start = 0
local bin_vol={}
local bin_arp={}
local idx={}

for k, v in pairs(channel) do
    local temp = io.open(output.."channel_" .. k .. ".txt", "w")
    bin_vol[k]={}
    bin_arp[k]={}
    idx[k]=1
    print("Ch="..k.. " arp " .. #v.arp)
    for j = 1, #v.arp, 255 do
        bin_vol[k][idx[k]]={}
        bin_arp[k][idx[k]]={}        
        temp:write("vol\n")
        for i = 1, 255 do
            local dat = v.vol[i + j - 1]
            if dat == nil then
                --break
                dat=0
            end
            temp:write(dat .. " ")
            dat=tonumber(dat)
            if dat<0 then --负数使用补码方式存储
               dat=256+dat
            end
            table.insert(bin_vol[k][idx[k]], dat)
        end
        temp:write("\n")
        temp:write("arp\n")
        for i = 1, 255 do            
            local dat = v.arp[i + j - 1]
            if dat == nil then
                --break
                dat=0
            end
            temp:write(dat .. " ")
            dat=tonumber(dat)
            
            if dat<0 then --负数使用补码方式存储
                dat=256+dat
            end            
            table.insert(bin_arp[k][idx[k]], dat)
        end
        temp:write("\n")
        idx[k]=idx[k]+1
    end

    io.close(temp)
   --break
end

--[[
local vol,arp=parse_mml_line(str1)
dump(vol,"vol")
dump(arp,"arp")
]]

--dump(bin_vol["9"][1])

for k, v in pairs(bin_arp) do
   -- dump(v,k)

    for m,n in ipairs(v) do
        local idx=string.format( "%02d",m)
        local filename=output..idx.."-ch-"..k..".fui"
        local file = io.open(filename, "w+b")
        local offset={}
        offset[1]=0
        offset[2]=#header
        offset[3]=offset[2]+#n
        offset[4]=offset[3]+#mider
        offset[5]=offset[4]+#n

        fileWriteData(file, header, offset[1])
        fileWriteData(file, bin_vol[k][m],offset[2])   
        fileWriteData(file, mider,offset[3])
        fileWriteData(file, n,offset[4])
        fileWriteData(file, ender, offset[5])
        io.close(file)
        --print("channel="..filename)
    end
    
end