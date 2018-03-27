# AWS S3 example
# to put array into a bucket 'slimbucket' in region 'us-west-2' under name 'tmp/test/small' 

# safe for multiple Cloud providers mixed in the same code

using AWSCore
using CloudExtras

aws = aws_config(region="us-west-2")

a=randn(11,12,13);

AWSextras.array_put(aws, "slimbucket", "tmp/test/small", a);

A=AWSextras.array_get(aws, "slimbucket", "tmp/test/small");

AWSextras.array_delete(aws, "slimbucket", "tmp/test/small");

