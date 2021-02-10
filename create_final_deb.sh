make clean
echo "Building Xcode 12 slice..."
make FINALPACKAGE=1 XCODE_12_SLICE=1
mkdir plipo_tmp
cp ./.theos/obj/CCSupport.dylib ./plipo_tmp/CCSupport_xcode12_arm64e.dylib
make clean
echo "Building other slices..."
make FINALPACKAGE=1 XCODE_12_SLICE=0
# plipo: patched up version of lipo by Matchstic (see: https://github.com/theos/theos/issues/563#issuecomment-759609420)
# I renamed it from lipo to plipo and put it into /usr/local/bin
plipo ./.theos/obj/CCSupport.dylib ./plipo_tmp/CCSupport_xcode12_arm64e.dylib -output ./.theos/obj/CCSupport.dylib -create
rm -rf plipo_tmp
echo "Packaging..."

# just running make package works because theos detects that the dylib
# already exists so it just uses that to package instead of recompiling

if [ "$1" == "install" ]; then
make package FINALPACKAGE=1 install
else
make package FINALPACKAGE=1
fi