using Infiltrator
using MdfReader

mdf = "test\\testfiles\\test.mdf"
id,hd,dg = channelNames(mdf)
@show id
@show hd

dg
