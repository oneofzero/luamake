local xcode_tools = [[/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin]]

local flags;
function mac_config(proj,arch)
    proj.compiler = xcode_tools .. "/clang"
    proj.cxx_compiler = xcode_tools .. "/clang -x c++"
    proj.ar = xcode_tools .. "/air-ar rcv "
    proj.linker = xcode_tools .. "/clang++"
    if arch=="arm" then
        proj:AddFlag([[-target arm64-apple-macos12.6]])
        proj:AddLinkFlag("-target arm64-apple-macos12.6")
    else
        proj:AddFlag([[-target x86_64-apple-macos12.6]])
        proj:AddLinkFlag("-target x86_64-apple-macos12.6")
    end
    
    for _,f in ipairs(flags) do
        proj:AddFlag(f)
    end

    proj:AddLinkFlag([[-std\=gnu++2]])
    proj:AddLinkFlag("-Xlinker -reproducible")
    proj:AddLinkFlag(" -dynamiclib -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -Os")
    
end

flags={
[[-std\=gnu++20]],
[[-Wnon-modular-include-in-framework-module]],
[[-Werror\=non-modular-include-in-framework-module]],
[[-Wno-trigraphs -fpascal-strings]],
[[-Os]],
[[-fno-common]],
[[-Wno-missing-field-initializers]],
[[-Wno-missing-prototypes]],
[[-Werror\=return-type -Wdocumentation]],
[[-Wunreachable-code]],
[[-Wquoted-include-in-framework-header]],
[[-Werror\=deprecated-objc-isa-usage]],
[[-Werror\=objc-root-class]],
[[-Wno-non-virtual-dtor]],
[[-Wno-overloaded-virtual]],
[[-Wno-exit-time-destructors]],
[[-Wno-missing-braces]],
[[-Wparentheses]],
[[-Wswitch]],
[[-Wunused-function]],
[[-Wno-unused-label]],
[[-Wno-unused-parameter]],
[[-Wunused-variable]],
[[-Wunused-value]],
[[-Wempty-body]],
[[-Wuninitialized]],
[[-Wconditional-uninitialized]],
[[-Wno-unknown-pragmas]],
[[-Wno-shadow]],
[[-Wno-four-char-constants]],
[[-Wno-conversion]],
[[-Wconstant-conversion]],
[[-Wint-conversion]],
[[-Wbool-conversion]],
[[-Wenum-conversion]],
[[-Wno-float-conversion]],
[[-Wnon-literal-null-conversion]],
[[-Wobjc-literal-conversion]],
[[-Wshorten-64-to-32]],
[[-Wno-newline-eof]],
[[-Wno-c++11-extensions]],
[[-Wno-implicit-fallthrough]],
[[-isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk]],
[[-fstrict-aliasing]],
[[-Wdeprecated-declarations]],
[[-Winvalid-offsetof]],
[[-Wno-sign-conversion]],
[[-Winfinite-recursion]],
[[-Wmove]],
[[-Wcomma]],
[[-Wblock-capture-autoreleasing]],
[[-Wstrict-prototypes]],
[[-Wrange-loop-analysis]],
[[-Wno-semicolon-before-method-body]],
[[-Wunguarded-availability]],
}