# AWS S3 example
# to put array into a bucket 'slimbucket' in region 'us-west-2' under name 'tmp/test/small' 

# safe only if using one Cloud provider

using AWSCore
using CloudExtras.AWSextras

aws = aws_config(region="us-west-2")

a=randn(11,12,13);

array_put(aws, "slimbucket", "tmp/test/small", a);

A=array_get(aws, "slimbucket", "tmp/test/small");

array_delete(aws, "slimbucket", "tmp/test/small");

