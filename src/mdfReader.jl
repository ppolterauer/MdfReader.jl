module mdfReader
	import InteractiveUtils.subtypes
	export HDBLOCK,IDBLOCK,DGBLOCK,TXBLOCK,PRBLOCK,BLOCK
	export linkoffset,BlockLink
	export channelNames

	struct CHAR
		x :: UInt8
	end
	Base.Char(c::CHAR) = Base.Char(c.x)
	Base.show(io::IO,c::CHAR) = print(io,Char(c))
	Base.string(c::NTuple{x,CHAR}) where x = join(Char.(c))
	Base.show(io::IO,c::NTuple{x,CHAR}) where x= print(io,string(c))
	
	nCHAR(n) = NTuple{n,CHAR}

	struct BlockLink
	    target :: UInt32
	end
	isNill(b) = iszero(b.target)
	Base.convert(::Type{BlockLink}, x::Int64) = BlockLink(x)
	Base.show(io::IO,b::BlockLink)=print(io,"byteNr: $(b.target)")
	Base.seek(io::IO,b::BlockLink)=seek(io,b.target)


	struct BlockHeader
	    type                   :: nCHAR(2)
	    size                   :: UInt16
	end
	Base.string(hd::BlockHeader) = string(hd.type)
	typestr(hd::BlockHeader) = string(hd)*"BLOCK"


	abstract type BLOCK end
	header(b::BLOCK) = b.header

	struct HDBLOCK<:BLOCK
	    header :: BlockHeader
	    dataGroupBlock              :: BlockLink
	    fileComment                 :: BlockLink
	    programBlock                :: BlockLink
	    numberDataGroups            :: UInt16
	    date                        :: nCHAR(10)
	    time                        :: nCHAR(8)
	    author                      :: nCHAR(32)
	    organization                :: nCHAR(32)
	    project                     :: nCHAR(32)
	    subject                     :: nCHAR(32)
	    timeStamp                   :: UInt64
	    utcTimeOffset               :: Int16
	    timeQuality                 :: UInt16
	    timerIdentification         :: nCHAR(32)
	    HDBLOCK() = new()
	end

	struct IDBLOCK<:BLOCK
	    fileIdentifier              :: nCHAR(8)
	    formatIdentifier            :: nCHAR(8)
	    programIdentifier           :: nCHAR(8)
	    defaultByteOrder            :: UInt16
	    defaultFloatingPointFormat  :: UInt16
	    versionNumber               :: UInt16
	    codePageNumber              :: UInt16
	    reserved                    :: nCHAR(28)
	    standardFlags               :: UInt16
	    customFlags                 :: UInt16
	    IDBLOCK() = new()
	end

	struct DGBLOCK<:BLOCK
	    header :: BlockHeader
	    nextDataGroupBlock          :: BlockLink
	    firstChannelGroupBlock      :: BlockLink
	    triggerBlock                :: BlockLink
	    dataBlock                   :: BlockLink
	    numberChannelGroups         :: UInt16
	    numverRecordIDs             :: UInt16
	    Reserved                    :: UInt32
	    DGBLOCK() = new()
	end

	struct TXBLOCK<:BLOCK
	    header  :: BlockHeader
	    text    :: String
	    TXBLOCK() = new()
	end
	struct PRBLOCK<:BLOCK
	    header  :: BlockHeader
	    text    :: String
	    PRBLOCK() = new()
	end
	function Base.read(io::IO,b::TXBLOCK)
	    hd = read(io,BlockHeader)
	    nb = size(hd)-sizeof(hd)
	    str = String(Char.(read(io,nb)))
	end
	linkfields(b::DataType) = [fieldname(b,i) for i in 1:fieldcount(b) if fieldtype(b,i)==BlockLink]
	linkfields(b) = linkfields(typeof(b))

	isBlockType(hd::BlockHeader) = typestr(hd) in string.(subtypes(BLOCK))
	type(hd::BlockHeader) = eval(Symbol(typestr(hd)))

	"""
		linkoffset(b)

	returns the link field offset for the given block type
	"""
	function linkoffset(b::Type{T}) where T<:BLOCK
		[fieldoffset(b,i) for i in 1:fieldcount(b) if fieldtype(b,i)==BlockLink]
	end	

	function readlink(io,pos)
		seek(io,pos)
		read(io,BlockLink)
	end	
	function readlinks(io,hd)
		sz  = sizeof(hd)
		loffs = linkoffset(type(hd))
		pos   = loffs .+ position(io) .- sz
		links = [readlink(io,p) for p in pos]
	end
	Base.size(hd::BlockHeader) = hd.size


	struct Block
	    header   :: BlockHeader
	    position :: BlockLink
	    links    :: Vector{BlockLink}
	end
	links(b) = b.links
	type(b) = type(b.header)
	function Base.read(io::IO,x)
		if isbits(x)
			read(io,typeof(x))
		end
	end
	function Base.read(io::IO,d::DataType)
	    a = Ref{d}()
	    read!(io,a)
	    a[]
	end
	Base.show(io::IO,b::BlockHeader)=print(io,"Block
	  type: $(typestr(b))
	  size: $(size(b))
	")
	function readBlock(io::IO)
		pos = position(io)
		hd  = read(io,BlockHeader)
		sz  = hd.size
		val = valid(hd) # check validity of block header
		if val
			links = readlinks(io,hd)
		else
			@warn "Invalid block header encountered at $pos\n"*repr(hd)
			links = []
		end
		# move to end of block
		if val seek(io,pos+sz) end
		(Block(hd,pos,links),val)
	end
	function readBlocks(io::IO)
		blocks = Vector{Block}(undef,0)
		id = read(io,IDBLOCK) # file should always contain a identifier header
		val = true;
		while ~eof(io) & val
		    b,val = readBlock(io)
		    if val push!(blocks,b) end # if valid push header
		end
		blocks
	end
	valid(hd::BlockHeader) = (size(hd)>0) & isBlockType(hd)
	valid(b::BLOCK) = valid(header(b)) & (typestr(header(b))==string(typeof(b)))
	function test()
		@show "hallasdasdadasdsadasdasdo"
	end
	function channelNames(mdf)
		open(mdf) do io
			id = read(io,IDBLOCK)
			hd = read(io,HDBLOCK)
			# get channel group link from hd block
			dglink = hd.dataGroupBlock
			nDG    = hd.numberDataGroups
			## read all dgBlocks
		    dgBlocks 	= Vector{DGBLOCK}(undef,0)
		    seek(io,dglink)
		    done 		= false
		    while ~done
		    	dg = read(io,DGBLOCK)
		    	@show dg
		    	if valid(dg) 
		    		push!(dgBlocks,dg)
		    		if isNill(dg.nextDataGroupBlock)
		    			done = true
	    			else
	    				seek(io,dg.nextDataGroupBlock)
		    		end
		    	else
		    		done = true
		    	end
		    end
		    @show dgBlocks
		end
	end
end