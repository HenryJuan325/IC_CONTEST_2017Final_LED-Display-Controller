design=$1
version=$2
echo $design
echo $version

mkdir "result_$version"

cp "../01_RTL/""$design"".v" "./result_""$version""/"
cp "../02_SYN/""$design""_syn.v" "./result_""$version""/"
cp "../02_SYN/""$design""_syn.sdf" "./result_""$version""/"
cp "../report.$version" "./result_$version/report.$version"

tar -cvf "result_""$version"".tar" "result_""$version"

