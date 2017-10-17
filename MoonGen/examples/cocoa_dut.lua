local mg 	= require "moongen" 
local memory	= require "memory"
local device	= require "device"
local stats	= require "stats"
local log	= require "log"

local QUEUE_CNT = 1
local TIMESTAMP_PORT = 2346

function configure(parser)
	parser:description("Receives traffic and responds back")
	parser:argument("txDev", "Device to transmit from."):convert(tonumber)
	parser:argument("rxDev", "Device to receive from."):convert(tonumber)
    parser:option("-r --respond", "respond or not"):default(0):convert(tonumber):target("respond")
end

function master(args)
	local txDev, rxDev
	if args.txDev == args.rxDev then
		-- sending and receiving from the same port
		txDev = device.config{port = args.txDev, rxQueues = QUEUE_CNT, txQueues = QUEUE_CNT}
		rxDev = txDev
	else
		-- two different ports, different configuration
		txDev = device.config{port = args.txDev, rxQueues = 1, txQueues = QUEUE_CNT}
		rxDev = device.config{port = args.rxDev, rxQueues = QUEUE_CNT}
	end

	-- wait until the links are up
	device.waitForLinks()

    for i = 0, QUEUE_CNT - 1 do			
	    mg.startTask("counterSlave", rxDev:getRxQueue(i), i, txDev, txDev:getTxQueue(i), args.respond)
    end
	
    -- wait until all tasks are finished
	mg.waitForTasks()
end

function copy(obj)
  if type(obj) ~= 'table' then return obj end
  local res = {}
  for k, v in pairs(obj) do res[copy1(k)] = copy1(v) end
  return res
end

function counterSlave(rxqueue, queue_id, txDev, txqueue, respond)
	local rxbufs = memory.bufArray()
	local rxCtr = stats:newPktRxCounter("Queue" .. queue_id, "plain")
 
    local src_mac = txDev:getMac(true)
    while mg.running(100) do
		local rx = rxqueue:recv(rxbufs)
		for i = 1, rx do
			local buf = rxbufs[i]
			rxCtr:countPacket(buf)
		    
            if respond > 0 then
                local pkt = buf:getUdpPacket()
                local dstPort = pkt.udp:getDstPort()
                if not (dstPort == TIMESTAMP_PORT) then 
                    --local tmp = pkt.ip4.src:get()
                    --pkt.eth.dst:set(pkt.eth.src:get())
                    pkt.eth.src:set(src_mac)
                    --[[pkt.ip4.src:set(pkt.ip4.dst:get())
                    pkt.ip4.dst:set(tmp)
                    pkt.ip4:calculateChecksum()
                    local tmp_port = pkt.udp:getSrcPort()
                    pkt.udp:setSrcPort(pkt.udp:getDstPort())
                    pkt.udp:setDstPort(tmp_port)
                    pkt.udp:setChecksum(0)--]]
                end
            end
		end
         
        rxCtr:update()

        if respond > 0 then
            --rxbufs:offloadUdpChecksums()
            txqueue:sendN(rxbufs, rx)
		else
            rxbufs:freeAll()
        end
	end
    rxCtr:finalize()
end

