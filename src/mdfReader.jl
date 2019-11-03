module MdfReader
	import InteractiveUtils.subtypes
	# export HDBLOCK,IDBLOCK,DGBLOCK,TXBLOCK,PRBLOCK,BLOCK
	export linkoffset,BlockLink
	export channelNames

	struct CHAR
		x :: UInt8
	end
	struct BOOL
		x :: UInt16
	end
	struct REAL
		x :: Float64
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
	"""
		BLOCK(hd)
		instantiates the Block depending on its header
	"""
	function BLOCK(hd::BlockHeader)
		getfield(MdfReader, Symbol(typestr(hd)))()
	end
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

	struct CGBLOCK<:BLOCK
	    header 						:: BlockHeader
    	nextChannelGroupBlock       :: BlockLink
	    firstChannelBlock      		:: BlockLink
	    comment                		:: BlockLink
	    dataBlock                   :: BlockLink
	    recordID			        :: UInt16
	    numberChannels              :: UInt16
	    sizeDataRecord              :: UInt16
		numberRecords	            :: UInt32
		firstSampleReductionBlock   :: BlockLink
	    CGBLOCK() = new()
	end

	struct CNBLOCK<:BLOCK
		header 						:: BlockHeader
		nextChannelBlock	        :: BlockLink
		conversionFormula      		:: BlockLink
		sourceDependingExtension   	:: BlockLink
		dependencyBlock	 			:: BlockLink
		comment 		 			:: BlockLink
		channelType			        :: UInt16
		shortSignalName             :: nCHAR(32)
		signalDescription           :: nCHAR(128)
		startOffset                 :: UInt16
		numberOfBits	            :: UInt16
		signalDataType	            :: UInt16
		valueRangeValid	            :: BOOL
		minimumSignalValue 		    :: REAL
		maximumSignalValue 		    :: REAL
		samplingRate 				:: REAL
		longSignalName	 			:: BlockLink
		displayName		 			:: BlockLink
		additionalByteOffset		:: UInt16
		CNBLOCK() = new()
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

	# TODO: make read block such that it only reads the blocksize number of
	# fields and makes the other fields without content. (e.g. zero)

	linkfields(b::DataType) = [fieldname(b,i) for i in 1:fieldcount(b) if fieldtype(b,i)==BlockLink]
	linkfields(b) = linkfields(typeof(b))

	isBlockType(hd::BlockHeader) = type(hd) in subtypes(BLOCK)
	type(hd::BlockHeader) = getfield(Main,Symbol(typestr(hd)))

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
	# function readBlock(io::IO)
	# 	pos = position(io)
	# 	hd  = read(io,BlockHeader)
	# 	sz  = hd.size
	#
	# 	val = valid(hd) # check validity of block header
	# 	if val
	# 		b = BLOCK(hd)
	# 	end
	# 	if val
	# 		links = readlinks(io,hd)
	# 	else
	# 		@warn "Invalid block header encountered at $pos\n"*repr(hd)
	# 		links = []
	# 	end
	# end
	function readBlock(io)
		hd = read(io,BlockHeader)
		if valid(hd)
			b = read(io,type(hd)) # call a generic block reader
		else
			@error "invalid header:\n $hd\n encountered"
		end
		if valid(b)
			b
		else
			@error "invalid block: \n $b\n encountered"
		end
	end
	function readBlock(io,link::BlockLink)
		seek(io,link)
		readBlock(io)
	end
	# function readBlocks(io::IO)
	# 	blocks = Vector{Block}(undef,0)
	# 	id = read(io,IDBLOCK) # file should always contain a identifier header
	# 	val = true;
	# 	while ~eof(io) & val
	# 	    b,val = readBlock(io)
	# 	    if val push!(blocks,b) end # if valid push header
	# 	end
	# 	blocks
	# end
	function next(b::DGBLOCK)
		b.nextDataGroupBlock
	end
	valid(hd::BlockHeader) = (size(hd)>0) & isBlockType(hd)
	function valid(b::BLOCK)
		valid(header(b)) & (typestr(header(b))==string(typeof(b)))
	end
	function channelNames(mdf)
		open(mdf) do io
			id = read(io,IDBLOCK)
			hd = read(io,HDBLOCK)

			dgs 	 = Array{DGBLOCK,1}(undef,0)
			dgblock  = readBlock(io,hd.dataGroupBlock)
			dglink 	 = next(dgblock)
			if dglink
				@show b = readBlock(io,dglink)
				push!(dgs,b)
			end

			# dataGroups = []
			# if valid(dg)
			# # get channel group link from hd block
			# dglink = hd.dataGroupBlock
			# nDG    = hd.numberDataGroups


			(id,hd,dgblock)

		    # done 		= false
		    # while ~done
		    # 	if valid(dg)
		    # 		push!(dgBlocks,dg)
		    # 		if isNill(dg.nextDataGroupBlock)
		    # 			done = true
	    	# 		else
	    	# 			seek(io,dg.nextDataGroupBlock)
		    # 		end
		    # 	else
		    # 		done = true
		    # 	end
		    # end
		end
	end
end
