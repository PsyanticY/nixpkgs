{ stdenv, lib, fetchFromGitHub, fetchurl, fetchzip, fetchgit, mercurial, python27, setJavaClassPath,
  zlib, makeWrapper, openjdk, unzip, git, clang, llvm, which, icu, ruby, bzip2, glibc
  # gfortran, readline, bzip2, lzma, pcre, curl, ed, tree ## WIP: fastr deps
}:

let
  version = "19.1.1";
  truffleMake = ./truffle.make;
  makeMxGitCache = list: out: ''
     mkdir ${out}
    ${lib.concatMapStrings ({ url, name, rev, sha256 }: ''
      mkdir -p ${out}/${name}
      cp -rf ${fetchgit { inherit url rev sha256; }}/* ${out}/${name}
    ''
    ) list}

    # # GRAAL-NODEJS # #
    chmod -R +rw ${out}
    sed -i "s|#include \"../../../../mxbuild/trufflenode/coremodules/node_snapshots.h\"| \
           #include \"$NIX_BUILD_TOP/mxbuild/graal-nodejs/trufflenode/coremodules/node_snapshots.h\"|g" \
      ${out}/graaljs/graal-nodejs/deps/v8/src/graal/callbacks.cc

    # patch the shebang in python script runner
    chmod -R +rw ${out}/graaljs/graal-nodejs/mx.graal-nodejs/python2
    patchShebangs ${out}/graaljs/graal-nodejs/mx.graal-nodejs/python2/python

    cd ${out}
    hg init
    hg add
    hg commit -m 'dummy commit'
    hg tag      ${lib.escapeShellArg "vm${version}"}
    hg checkout ${lib.escapeShellArg "vm${version}"}
  '';

  # pre-download some cache entries ('mx' will not be able to download under nixbld)
  makeMxCache = list:
    stdenv.mkDerivation {
      name = "mx-cache";
      buildInputs = [ unzip ];
      buildCommand = with lib; ''
        mkdir $out
        ${lib.concatMapStrings
          ({url, name, sha1, isNinja ? false}: ''
            install -D ${fetchurl { inherit url sha1; }} $out/${name}
            echo -n ${sha1} > $out/${name}.sha1
            ${if isNinja then ''
                export BASENAME=${removeSuffix ".zip" name}
                mkdir "$out/$BASENAME.extracted" &&
                unzip "$out/${name}" -d "$out/$BASENAME.extracted"

                # Ninja is called later in the build process
                if [ -f $out/$BASENAME.extracted/ninja ]; then
                  patchelf --set-interpreter \
                    "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                    --set-rpath "${stdenv.cc.cc.lib}/lib64" \
                    $out/$BASENAME.extracted/ninja
                fi
              ''
            else ""}
         '') list}
      '';
    };

  jvmci8-mxcache = [
    rec { sha1 = "53addc878614171ff0fcbc8f78aed12175c22cdb"; name = "JACOCOCORE_0.8.4_${sha1}/jacococore-0.8.4.jar";                                   url = mirror://maven/org/jacoco/org.jacoco.core/0.8.4/org.jacoco.core-0.8.4.jar; }
    rec { sha1 = "9bd1fa334d941005bc9ab3ac92478a590f5b7d73"; name = "JACOCOCORE_0.8.4_${sha1}/jacococore-0.8.4.sources.jar";                           url = mirror://maven/org/jacoco/org.jacoco.core/0.8.4/org.jacoco.core-0.8.4-sources.jar; }
    rec { sha1 = "e5ca9511493b7e3bc2cabdb8ded92e855f3aac32"; name = "JACOCOREPORT_0.8.4_${sha1}/jacocoreport-0.8.4.jar";                               url = mirror://maven/org/jacoco/org.jacoco.report/0.8.4/org.jacoco.report-0.8.4.jar; }
    rec { sha1 = "eb61e479b35b467954f28a565c094c563b790e19"; name = "JACOCOREPORT_0.8.4_${sha1}/jacocoreport-0.8.4.sources.jar";                       url = mirror://maven/org/jacoco/org.jacoco.report/0.8.4/org.jacoco.report-0.8.4-sources.jar; }
    rec { sha1 = "869021a6d90cfb008b12e83fccbe42eca29e5355"; name = "JACOCOAGENT_0.8.4_${sha1}/jacocoagent-0.8.4.jar";                                 url = mirror://maven/org/jacoco/org.jacoco.agent/0.8.4/org.jacoco.agent-0.8.4-runtime.jar; }
    rec { sha1 = "306816fb57cf94f108a43c95731b08934dcae15c"; name = "JOPTSIMPLE_4_6_${sha1}/joptsimple-4-6.jar";                                       url = mirror://maven/net/sf/jopt-simple/jopt-simple/4.6/jopt-simple-4.6.jar; }
    rec { sha1 = "9cd14a61d7aa7d554f251ef285a6f2c65caf7b65"; name = "JOPTSIMPLE_4_6_${sha1}/joptsimple-4-6.sources.jar";                               url = mirror://maven/net/sf/jopt-simple/jopt-simple/4.6/jopt-simple-4.6-sources.jar; }
    rec { sha1 = "fa29aa438674ff19d5e1386d2c3527a0267f291e"; name = "ASM_7.1_${sha1}/asm-7.1.jar";                                                     url = mirror://maven/org/ow2/asm/asm/7.1/asm-7.1.jar; }
    rec { sha1 = "9d170062d595240da35301362b079e5579c86f49"; name = "ASM_7.1_${sha1}/asm-7.1.sources.jar";                                             url = mirror://maven/org/ow2/asm/asm/7.1/asm-7.1-sources.jar; }
    rec { sha1 = "a3662cf1c1d592893ffe08727f78db35392fa302"; name = "ASM_TREE_7.1_${sha1}/asm-tree-7.1.jar";                                           url = mirror://maven/org/ow2/asm/asm-tree/7.1/asm-tree-7.1.jar; }
    rec { sha1 = "157238292b551de8680505fa2d19590d136e25b9"; name = "ASM_TREE_7.1_${sha1}/asm-tree-7.1.sources.jar";                                   url = mirror://maven/org/ow2/asm/asm-tree/7.1/asm-tree-7.1-sources.jar; }
    rec { sha1 = "379e0250f7a4a42c66c5e94e14d4c4491b3c2ed3"; name = "ASM_ANALYSIS_7.1_${sha1}/asm-analysis-7.1.jar";                                   url = mirror://maven/org/ow2/asm/asm-analysis/7.1/asm-analysis-7.1.jar; }
    rec { sha1 = "36789198124eb075f1a5efa18a0a7812fb16f47f"; name = "ASM_ANALYSIS_7.1_${sha1}/asm-analysis-7.1.sources.jar";                           url = mirror://maven/org/ow2/asm/asm-analysis/7.1/asm-analysis-7.1-sources.jar; }
    rec { sha1 = "431dc677cf5c56660c1c9004870de1ed1ea7ce6c"; name = "ASM_COMMONS_7.1_${sha1}/asm-commons-7.1.jar";                                     url = mirror://maven/org/ow2/asm/asm-commons/7.1/asm-commons-7.1.jar; }
    rec { sha1 = "a62ff3ae6e37affda7c6fb7d63b89194c6d006ee"; name = "ASM_COMMONS_7.1_${sha1}/asm-commons-7.1.sources.jar";                             url = mirror://maven/org/ow2/asm/asm-commons/7.1/asm-commons-7.1-sources.jar; }
    rec { sha1 = "ec2544ab27e110d2d431bdad7d538ed509b21e62"; name = "COMMONS_MATH3_3_2_${sha1}/commons-math3-3-2.jar";                                 url = mirror://maven/org/apache/commons/commons-math3/3.2/commons-math3-3.2.jar; }
    rec { sha1 = "cd098e055bf192a60c81d81893893e6e31a6482f"; name = "COMMONS_MATH3_3_2_${sha1}/commons-math3-3-2.sources.jar";                         url = mirror://maven/org/apache/commons/commons-math3/3.2/commons-math3-3.2-sources.jar; }
    rec { sha1 = "442447101f63074c61063858033fbfde8a076873"; name = "JMH_1_21_${sha1}/jmh-1-21.jar";                                                   url = mirror://maven/org/openjdk/jmh/jmh-core/1.21/jmh-core-1.21.jar; }
    rec { sha1 = "a6fe84788bf8cf762b0e561bf48774c2ea74e370"; name = "JMH_1_21_${sha1}/jmh-1-21.sources.jar";                                           url = mirror://maven/org/openjdk/jmh/jmh-core/1.21/jmh-core-1.21-sources.jar; }
    rec { sha1 = "7aac374614a8a76cad16b91f1a4419d31a7dcda3"; name = "JMH_GENERATOR_ANNPROCESS_1_21_${sha1}/jmh-generator-annprocess-1-21.jar";         url = mirror://maven/org/openjdk/jmh/jmh-generator-annprocess/1.21/jmh-generator-annprocess-1.21.jar; }
    rec { sha1 = "fb48e2a97df95f8b9dced54a1a37749d2a64d2ae"; name = "JMH_GENERATOR_ANNPROCESS_1_21_${sha1}/jmh-generator-annprocess-1-21.sources.jar"; url = mirror://maven/org/openjdk/jmh/jmh-generator-annprocess/1.21/jmh-generator-annprocess-1.21-sources.jar; }
    rec { sha1 = "2973d150c0dc1fefe998f834810d68f278ea58ec"; name = "JUNIT_${sha1}/junit.jar";                                                         url = mirror://maven/junit/junit/4.12/junit-4.12.jar; }
    rec { sha1 = "a6c32b40bf3d76eca54e3c601e5d1470c86fcdfa"; name = "JUNIT_${sha1}/junit.sources.jar";                                                 url = mirror://maven/junit/junit/4.12/junit-4.12-sources.jar; }
    rec { sha1 = "42a25dc3219429f0e5d060061f71acb49bf010a0"; name = "HAMCREST_${sha1}/hamcrest.jar";                                                   url = mirror://maven/org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar; }
    rec { sha1 = "1dc37250fbc78e23a65a67fbbaf71d2e9cbc3c0b"; name = "HAMCREST_${sha1}/hamcrest.sources.jar";                                           url = mirror://maven/org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3-sources.jar; }
    rec { sha1 = "0d031013db9a80d6c88330c42c983fbfa7053193"; name = "hsdis_${sha1}/hsdis.so";                                                          url = "https://lafo.ssw.uni-linz.ac.at/pub/graal-external-deps/hsdis/intel/hsdis-amd64-linux-${sha1}.so"; }
  ];

  graal-mxcache = jvmci8-mxcache ++ [
    rec { sha1 = "a990b2dba1c706f5c43c56fedfe70bad9a695852"; name = "LLVM_WRAPPER_${sha1}/llvm-wrapper.jar";                                           url = mirror://maven/org/bytedeco/javacpp-presets/llvm/6.0.1-1.4.2/llvm-6.0.1-1.4.2.jar; }
    rec { sha1 = "decbd95d46092fa9afaf2523b5b23d07ad7ad6bc"; name = "LLVM_WRAPPER_${sha1}/llvm-wrapper.sources.jar";                                   url = mirror://maven/org/bytedeco/javacpp-presets/llvm/6.0.1-1.4.2/llvm-6.0.1-1.4.2-sources.jar; }
    rec { sha1 = "344483aefa15147c121a8fb6fb35a2406768cc5c"; name = "LLVM_PLATFORM_SPECIFIC_${sha1}/llvm-platform-specific.jar";                       url = mirror://maven/org/bytedeco/javacpp-presets/llvm/6.0.1-1.4.2/llvm-6.0.1-1.4.2-linux-x86_64.jar; }
    rec { sha1 = "503402aa0cf80fd95ede043c0011152c2b4556fd"; name = "LLVM_PLATFORM_${sha1}/llvm-platform.jar";                                         url = mirror://maven/org/bytedeco/javacpp-presets/llvm-platform/6.0.1-1.4.2/llvm-platform-6.0.1-1.4.2.jar; }
    rec { sha1 = "cfa6a0259d98bff5aa8d41ba11b4d1dad648fbaa"; name = "JAVACPP_${sha1}/javacpp.jar";                                                     url = mirror://maven/org/bytedeco/javacpp/1.4.2/javacpp-1.4.2.jar; }
    rec { sha1 = "fdb2d2c17f6b91cdd5421554396da8905f0dfed2"; name = "JAVACPP_${sha1}/javacpp.sources.jar";                                             url = mirror://maven/org/bytedeco/javacpp/1.4.2/javacpp-1.4.2-sources.jar; }
    rec { sha1 = "702ca2d0ae93841c5ab75e4d119b29780ec0b7d9"; name = "NINJA_SYNTAX_${sha1}/ninja-syntax.tar.gz";                                        url = "https://pypi.org/packages/source/n/ninja_syntax/ninja_syntax-1.7.2.tar.gz"; }
    rec { sha1 = "987234c4ce45505c21302e097c24efef4873325c"; name = "NINJA_${sha1}/ninja.zip";                                                         url = "https://github.com/ninja-build/ninja/releases/download/v1.8.2/ninja-linux.zip";
          isNinja = true; }
    rec { sha1 = "f2cfb09cee12469ff64f0d698b13de19903bb4f7"; name = "NanoHTTPD-WebSocket_${sha1}/nanohttpd-websocket.jar";                             url = mirror://maven/org/nanohttpd/nanohttpd-websocket/2.3.1/nanohttpd-websocket-2.3.1.jar; }
    rec { sha1 = "a8d54d1ca554a77f377eff6bf9e16ca8383c8f6c"; name = "NanoHTTPD_${sha1}/nanohttpd.jar";                                                 url = mirror://maven/org/nanohttpd/nanohttpd/2.3.1/nanohttpd-2.3.1.jar; }
    rec { sha1 = "946f8aa9daa917dd81a8b818111bec7e288f821a"; name = "ANTLR4_${sha1}/antlr4.jar";                                                       url = mirror://maven/org/antlr/antlr4-runtime/4.7.1/antlr4-runtime-4.7.1.jar; }
    rec { sha1 = "c3aeac59c022bdc497c8c48ed86fa50450e4896a"; name = "JLINE_${sha1}/jline.jar";                                                         url = mirror://maven/jline/jline/2.14.6/jline-2.14.6.jar; }
    rec { sha1 = "d0bdc21c5e6404726b102998e44c66a738897905"; name = "JAVA_ALLOCATION_INSTRUMENTER_${sha1}/java-allocation-instrumenter.jar";           url = mirror://maven/com/google/code/java-allocation-instrumenter/java-allocation-instrumenter/3.1.0/java-allocation-instrumenter-3.1.0.jar; }
    rec { sha1 = "0da08b8cce7bbf903602a25a3a163ae252435795"; name = "ASM5_${sha1}/asm5.jar";                                                        url = mirror://maven/org/ow2/asm/asm/5.0.4/asm-5.0.4.jar; }
    rec { sha1 = "396ce0c07ba2b481f25a70195c7c94922f0d1b0b"; name = "ASM_TREE5_${sha1}/asm-tree5.jar";                                                 url = mirror://maven/org/ow2/asm/asm-tree/5.0.4/asm-tree-5.0.4.jar; }
    rec { sha1 = "280c265b789e041c02e5c97815793dfc283fb1e6"; name = "LIBFFI_SOURCES_${sha1}/libffi-sources.tar.gz";                                    url = https://lafo.ssw.uni-linz.ac.at/pub/graal-external-deps/libffi-3.2.1.tar.gz; }
    rec { sha1 = "8819cea8bfe22c9c63f55465e296b3855ea41786"; name = "TruffleJSON_${sha1}/trufflejson.jar";                                             url = https://lafo.ssw.uni-linz.ac.at/pub/graal-external-deps/trufflejson-20180130.jar; }
    rec { sha1 = "9712a8124c40298015f04a74f61b3d81a51513af"; name = "CHECKSTYLE_8.8_${sha1}/checkstyle-8.8.jar";                                       url = https://lafo.ssw.uni-linz.ac.at/pub/graal-external-deps/checkstyle-8.8-all.jar; }
    rec { sha1 = "158ba6f2b346469b5f8083d1700c3f55b8b9082c"; name = "VISUALVM_COMMON_${sha1}/visualvm-common.tar.gz";                                  url = https://lafo.ssw.uni-linz.ac.at/pub/graal-external-deps/visualvm/visualvm-19_0_0-11.tar.gz; }
    rec { sha1 = "eb5ffa476ed2f6fac0ecd4bb2ae32741f9646932"; name = "VISUALVM_PLATFORM_SPECIFIC_${sha1}/visualvm-platform-specific.tar.gz";            url = https://lafo.ssw.uni-linz.ac.at/pub/graal-external-deps/visualvm/visualvm-19_0_0-11-linux-amd64.tar.gz; }
    rec { sha1 = "e6e60889b7211a80b21052a249bd7e0f88f79fee"; name = "Java-WebSocket_${sha1}/java-websocket.jar";                                       url = mirror://maven/org/java-websocket/Java-WebSocket/1.3.9/Java-WebSocket-1.3.9.jar; }
    rec { sha1 = "7a4d00d5ec5febd252a6182e8b6e87a0a9821f81"; name = "ICU4J_${sha1}/icu4j.jar";                                                         url = mirror://maven/com/ibm/icu/icu4j/62.1/icu4j-62.1.jar; }
    # This duplication of asm with underscore and minus is totally weird
    rec { sha1 = "c01b6798f81b0fc2c5faa70cbe468c275d4b50c7"; name = "ASM-6.2.1_${sha1}/asm-6.2.1.jar";                                                 url = mirror://maven/org/ow2/asm/asm/6.2.1/asm-6.2.1.jar; }
    rec { sha1 = "cee28077ac7a63d3de0b205ec314d83944ff6267"; name = "ASM-6.2.1_${sha1}/asm-6.2.1.sources.jar";                                         url = mirror://maven/org/ow2/asm/asm/6.2.1/asm-6.2.1-sources.jar; }
    rec { sha1 = "332b022092ecec53cdb6272dc436884b2d940615"; name = "ASM_TREE-6.2.1_${sha1}/asm-tree-6.2.1.jar";                                       url = mirror://maven/org/ow2/asm/asm-tree/6.2.1/asm-tree-6.2.1.jar; }
    rec { sha1 = "072bd64989090e4ed58e4657e3d4481d96f643af"; name = "ASM_TREE-6.2.1_${sha1}/asm-tree-6.2.1.sources.jar";                               url = mirror://maven/org/ow2/asm/asm-tree/6.2.1/asm-tree-6.2.1-sources.jar; }
    rec { sha1 = "e8b876c5ccf226cae2f44ed2c436ad3407d0ec1d"; name = "ASM_ANALYSIS-6.2.1_${sha1}/asm-analysis-6.2.1.jar";                               url = mirror://maven/org/ow2/asm/asm-analysis/6.2.1/asm-analysis-6.2.1.jar; }
    rec { sha1 = "b0b249bd185677648692e7c57b488b6d7c2a6653"; name = "ASM_ANALYSIS-6.2.1_${sha1}/asm-analysis-6.2.1.sources.jar";                       url = mirror://maven/org/ow2/asm/asm-analysis/6.2.1/asm-analysis-6.2.1-sources.jar; }
    rec { sha1 = "eaf31376d741a3e2017248a4c759209fe25c77d3"; name = "ASM_COMMONS-6.2.1_${sha1}/asm-commons-6.2.1.jar";                                 url = mirror://maven/org/ow2/asm/asm-commons/6.2.1/asm-commons-6.2.1.jar; }
    rec { sha1 = "667fa0f9d370e7848b0e3d173942855a91fd1daf"; name = "ASM_COMMONS-6.2.1_${sha1}/asm-commons-6.2.1.sources.jar";                         url = mirror://maven/org/ow2/asm/asm-commons/6.2.1/asm-commons-6.2.1-sources.jar; }
    # From here on the deps are new
    rec { sha1 = "400d664d7c92a659d988c00cb65150d1b30cf339"; name = "ASM_UTIL-6.2.1_${sha1}/asm-util-6.2.1.jar";                                       url = mirror://maven/org/ow2/asm/asm-util/6.2.1/asm-util-6.2.1.jar; }
    rec { sha1 = "c9f7246bf93bb0dc7fe9e7c9eca531a8fb98d252"; name = "ASM_UTIL-6.2.1_${sha1}/asm-util-6.2.1.sources.jar";                               url = mirror://maven/org/ow2/asm/asm-util/6.2.1/asm-util-6.2.1-sources.jar; }
    rec { sha1 = "4b52bd03014f6d080ef0528865c1ee50621e35c6"; name = "NETBEANS_PROFILER_${sha1}/netbeans-profiler.jar";                                 url = https://lafo.ssw.uni-linz.ac.at/pub/graal-external-deps/truffle/js/org-netbeans-lib-profiler-8.2-201609300101.jar; }
    rec { sha1 = "b5840706cc8ce639fcafeab1bc61da2d8aa37afd"; name = "NASHORN_INTERNAL_TESTS_${sha1}/nashorn-internal-tests.jar";                       url = https://lafo.ssw.uni-linz.ac.at/pub/graal-external-deps/truffle/js/nashorn-internal-tests-700f5e3f5ff2.jar; }
    rec { sha1 = "9577018f9ce3636a2e1cb0a0c7fe915e5098ded5"; name = "JACKSON_ANNOTATIONS_${sha1}/jackson-annotations.jar";                             url = mirror://maven/com/fasterxml/jackson/core/jackson-annotations/2.8.6/jackson-annotations-2.8.6.jar; }
    rec { sha1 = "2ef7b1cc34de149600f5e75bc2d5bf40de894e60"; name = "JACKSON_CORE_${sha1}/jackson-core.jar";                                           url = mirror://maven/com/fasterxml/jackson/core/jackson-core/2.8.6/jackson-core-2.8.6.jar; }
    rec { sha1 = "c43de61f74ecc61322ef8f402837ba65b0aa2bf4"; name = "JACKSON_DATABIND_${sha1}/jackson-databind.jar";                                   url = mirror://maven/com/fasterxml/jackson/core/jackson-databind/2.8.6/jackson-databind-2.8.6.jar; }
    rec { sha1 = "2838952e91baa37ac73ed817451268a193ba440a"; name = "JCODINGS_${sha1}/jcodings.jar";                                                   url = mirror://maven/org/jruby/jcodings/jcodings/1.0.40/jcodings-1.0.40.jar; }
    rec { sha1 = "0ed89e096c83d540acac00d6ee3ea935b4c905ff"; name = "JCODINGS_${sha1}/jcodings.sources.jar";                                           url = mirror://maven/org/jruby/jcodings/jcodings/1.0.40/jcodings-1.0.40-sources.jar; }
    rec { sha1 = "5dbb09787a9b8780737b71fbf942235ef59051b9"; name = "JONI_${sha1}/joni.jar";                                                           url = mirror://maven/org/jruby/joni/joni/2.1.25/joni-2.1.25.jar; }
    rec { sha1 = "505a09064f6e2209616f38724f6d97d8d889aa92"; name = "JONI_${sha1}/joni.sources.jar";                                                   url = mirror://maven/org/jruby/joni/joni/2.1.25/joni-2.1.25-sources.jar; }
    rec { sha1 = "c4f7d054303948eb6a4066194253886c8af07128"; name = "XZ-1.8_${sha1}/xz-1.8.jar";                                                       url = mirror://maven/org/tukaani/xz/1.8/xz-1.8.jar; }
    rec { sha1 = "9314d3d372b05546a33791fbc8dd579c92ebd16b"; name = "GNUR_${sha1}/gnur.tar.gz";                                                        url = http://cran.rstudio.com/src/base/R-3/R-3.5.1.tar.gz; }
    rec { sha1 = "90aa8308da72ae610207d8f6ca27736921be692a"; name = "ANTLR4_COMPLETE_${sha1}/antlr4-complete.jar";                                     url = https://lafo.ssw.uni-linz.ac.at/pub/graal-external-deps/antlr-4.7.1-complete.jar; }
  ];

  graal-mxcachegit = [
    { sha256 = "05z2830ng71bhgsxc0zyc74l1bz7hg54la8j1r99993fhhch4y36"; name = "graaljs";     url = "https://github.com/graalvm/graaljs.git";     rev = "vm-${version}"; }
    { sha256 = "0ai5x4n1c2lcfkfpp29zn1bcmp3khc5hvssyw1qr1l2zy79fxwjp"; name = "truffleruby"; url = "https://github.com/oracle/truffleruby.git";  rev = "vm-${version}"; }
    { sha256 = "010079qsl6dff3yca8vlzcahq9z1ppyr758shjkm1f7izwphjv7p"; name = "fastr";       url = "https://github.com/oracle/fastr.git";        rev = "vm-${version}"; }
    { sha256 = "0hcqbasqs0yb7p1sal63qbxqxh942gh5vzl95pfdlflmc2g82v4q"; name = "graalpython"; url = "https://github.com/graalvm/graalpython.git"; rev = "vm-${version}"; }
  ];

  ninja-syntax = python27.pkgs.buildPythonPackage rec {
    version = "1.7.2";
    pname = "ninja_syntax";
    doCheck = false;
    src = python27.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "07zg30m0khx55fv2gxxn7pqd549z0vk3x592mrdlk9l8krxwjb9l";
    };
  };

  findbugs = fetchzip {
    name   = "findbugs-3.0.0";
    url    = https://lafo.ssw.uni-linz.ac.at/pub/graal-external-deps/findbugs-3.0.0.zip;
    sha256 = "0sf5f9h1s6fmhfigjy81i109j1ani5kzdr4njlpq0mnkkh9fpr7m";
  };

  python27withPackages = python27.withPackages (ps: [ ninja-syntax ]);

in rec {

  mx = stdenv.mkDerivation rec {
    version = "5.223.0";
    pname = "mx";
    src = fetchFromGitHub {
      owner  = "graalvm";
      repo   = "mx";
      rev    = version;
      sha256 = "0q51dnm6n1472p93dxr4jh8d7cv09a70pq89cdgxwh42vapykrn9";
    };
    nativeBuildInputs = [ makeWrapper ];
    prePatch = ''
      cp mx.py bak_mx.py
    '';
    patches = [ ./001_mx.py.patch ];
    postPatch = ''
      mv mx.py internal_mx.py
      mv bak_mx.py mx.py
    '';
    buildPhase = ''
      substituteInPlace mx --replace /bin/pwd pwd

      # avoid crash with 'ValueError: ZIP does not support timestamps before 1980'
      substituteInPlace internal_mx.py --replace \
        'zipfile.ZipInfo(arcname, time.localtime(getmtime(join(root, f)))[:6])' \
        'zipfile.ZipInfo(arcname, time.strptime ("1 Jan 1980", "%d %b %Y"       )[:6])'
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp -dpR * $out/bin
      wrapProgram $out/bin/mx \
        --prefix PATH : ${lib.makeBinPath [ python27withPackages mercurial ]} \
        --set    FINDBUGS_HOME ${findbugs}
      makeWrapper ${python27}/bin/python $out/bin/mx-internal \
        --add-flags "$out/bin/internal_mx.py" \
        --prefix PATH : ${lib.makeBinPath [ python27withPackages mercurial ]} \
        --set    FINDBUGS_HOME ${findbugs}
    '';
    meta = with stdenv.lib; {
      homepage = https://github.com/graalvm/mx;
      description = "Command-line tool used for the development of Graal projects";
      license = licenses.gpl2;
      platforms = python27.meta.platforms;
    };
  };

  jvmci8 = stdenv.mkDerivation rec {
    version = "19.2-b01";
    pname = "jvmci";
    src = fetchFromGitHub {
      owner  = "graalvm";
      repo   = "graal-jvmci-8";
      rev    = "jvmci-${version}";
      sha256 = "0maipj871vaxvap4576m0pzblzqxfjjzmwap3ndd84ny8d6vbqaa";
    };
    buildInputs = [ mx mercurial openjdk ];
    postUnpack = ''
      # a fake mercurial dir to prevent mx crash and supply the version to mx
      ( cd $sourceRoot
        hg init
        hg add
        hg commit -m 'dummy commit'
        hg tag      ${lib.escapeShellArg src.rev}
        hg checkout ${lib.escapeShellArg src.rev}
      )
    '';
    patches = [ ./004_mx_jvmci.py.patch ];
    postPatch =''
      # The hotspot version name regex fix
      substituteInPlace mx.jvmci/mx_jvmci.py \
        --replace "\\d+.\\d+-b\\d+" "\\d+.\\d+-bga"
      substituteInPlace src/share/vm/jvmci/jvmciCompilerToVM.cpp \
        --replace 'method->name_and_sig_as_C_string(), method->native_function(), entry' \
                  'method->name_and_sig_as_C_string(), p2i(method->native_function()), p2i(entry)' || exit -1
    '';
    hardeningDisable = [ "fortify" ];
    NIX_CFLAGS_COMPILE = [
      "-Wno-error=format-overflow" # newly detected by gcc7
      "-Wno-error=nonnull"
    ];
    buildPhase = ''
      export MX_ALT_OUTPUT_ROOT=$NIX_BUILD_TOP/mxbuild
      export MX_CACHE_DIR=${makeMxCache jvmci8-mxcache}

      mx-internal --primary-suite . --vm=server -v build -DFULL_DEBUG_SYMBOLS=0
      mx-internal --primary-suite . --vm=server -v vm -version
      mx-internal --primary-suite . --vm=server -v unittest
    '';
    installPhase = ''
      mkdir -p $out
      mv openjdk1.8.0_*/linux-amd64/product/* $out
      install -v -m0555 -D $MX_CACHE_DIR/hsdis*/hsdis.so $out/jre/lib/amd64/hsdis-amd64.so
    '';
    # copy-paste openjdk's preFixup
    preFixup = ''
      # Propagate the setJavaClassPath setup hook from the JRE so that
      # any package that depends on the JRE has $CLASSPATH set up
      # properly.
      mkdir -p $out/nix-support
      printWords ${setJavaClassPath} > $out/nix-support/propagated-build-inputs

      # Set JAVA_HOME automatically.
      mkdir -p $out/nix-support
      cat <<EOF > $out/nix-support/setup-hook
      if [ -z "\''${JAVA_HOME-}" ]; then export JAVA_HOME=$out; fi
      EOF
    '';
    postFixup = openjdk.postFixup or null;
    dontStrip = true; # stripped javac crashes with "segmentaion fault"
    inherit (openjdk) meta;
  };

  graalvm8 = stdenv.mkDerivation rec {
    inherit version;
    pname = "graal";
    src = fetchFromGitHub {
      owner  = "oracle";
      repo   = "graal";
      rev    = "vm-${version}";
      sha256 = "0abx6adk91yzaf1md4qbidxykpqcgphh6j4hj01ry57s4if0j66f";
    };
    patches = [ ./002_setjmp.c.patch ./003_mx_truffle.py.patch ];
    buildInputs = [ mx zlib mercurial jvmci8 git clang llvm
                    python27withPackages which icu ruby bzip2
                    # gfortran readline bzip2 lzma pcre.dev curl ed ## WIP: fastr dependencies
                  ];
    postUnpack = ''
      cp ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc}/stdlib.h \
        $sourceRoot/sulong/projects/com.oracle.truffle.llvm.libraries.bitcode/include
      cp ${truffleMake} $TMP && mv *truffle.make truffle.make
      rm $sourceRoot/truffle/src/libffi/patches/others/0001-Add-mx-bootstrap-Makefile.patch
      # a fake mercurial dir to prevent mx crash and supply the version to mx
      ( cd $sourceRoot
        hg init
        hg add
        hg commit -m 'dummy commit'
        hg tag      ${lib.escapeShellArg src.rev}
        hg checkout ${lib.escapeShellArg src.rev}
      )
    '';
    postPatch = ''
      substituteInPlace substratevm/src/com.oracle.svm.core.posix/src/com/oracle/svm/core/posix/headers/PosixDirectives.java \
        --replace '<zlib.h>' '<${zlib.dev}/include/zlib.h>'
      substituteInPlace substratevm/src/com.oracle.svm.hosted/src/com/oracle/svm/hosted/image/CCLinkerInvocation.java \
        --replace 'cmd.add("-v");' 'cmd.add("-v"); cmd.add("-L${zlib}/lib");'
      substituteInPlace substratevm/src/com.oracle.svm.hosted/src/com/oracle/svm/hosted/c/codegen/CCompilerInvoker.java \
        --replace 'command.add(Platform.includedIn(Platform.WINDOWS.class) ? "CL" : "gcc");' \
          'command.add(Platform.includedIn(Platform.WINDOWS.class) ? "CL" : "${stdenv.cc}/bin/gcc");'
      substituteInPlace substratevm/src/com.oracle.svm.hosted/src/com/oracle/svm/hosted/image/CCLinkerInvocation.java \
        --replace 'protected String compilerCommand = "cc";' 'protected String compilerCommand = "${stdenv.cc}/bin/cc";'
      # prevent cyclical imports caused by identical <include> names
      substituteInPlace sulong/projects/com.oracle.truffle.llvm.libraries.bitcode/include/stdlib.h \
        --replace '# include <cstdlib>' '# include "${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc}/cstdlib"'
      # dragonegg can't seem to compile on nix, so let's not require it
      substituteInPlace sulong/mx.sulong/suite.py \
        --replace '"requireDragonegg" : True,' '"requireDragonegg" : False,'
      substituteInPlace truffle/mx.truffle/mx_truffle.py \
        --replace 'os.path.relpath(self.subject.delegate.dir, self.subject.suite.vc_dir)' \
                  'self.subject.delegate.dir'

      # Patch the native-image template, as it will be run during build
      chmod +x vm/mx.vm/launcher_template.sh && patchShebangs vm/mx.vm
      # Prevent random errors from too low maxRuntimecompilemethods
      substituteInPlace truffle/mx.truffle/macro-truffle.properties \
        --replace '-H:MaxRuntimeCompileMethods=1400' \
                  '-H:MaxRuntimeCompileMethods=28000'
    '';

    buildPhase = ''
      # make a copy of jvmci8
      mkdir $NIX_BUILD_TOP/jvmci8
      cp -dpR ${jvmci8}/* $NIX_BUILD_TOP/jvmci8
      chmod +w -R $NIX_BUILD_TOP/jvmci8

      export MX_ALT_OUTPUT_ROOT=$NIX_BUILD_TOP/mxbuild
      export MX_CACHE_DIR=${makeMxCache graal-mxcache}
      export MX_GIT_CACHE='refcache'
      export MX_GIT_CACHE_DIR=$NIX_BUILD_TOP/mxgitcache
      export JVMCI_VERSION_CHECK='ignore'
      export JAVA_HOME=$NIX_BUILD_TOP/jvmci8
      # export FASTR_RELEASE=true ## WIP
      ${makeMxGitCache graal-mxcachegit "$MX_GIT_CACHE_DIR"}
      cd $NIX_BUILD_TOP/source

      ( cd vm
        mx-internal -v --dynamicimports /substratevm,/tools,sulong,/graal-nodejs,graalpython build
      )
    '';

    installPhase = ''
      mkdir -p $out
      rm -rf $MX_ALT_OUTPUT_ROOT/vm/linux-amd64/GRAALVM_*STAGE1*
      cp -rf $MX_ALT_OUTPUT_ROOT/vm/linux-amd64/GRAALVM*/graalvm-unknown-${version}/* $out

      # BUG workaround http://mail.openjdk.java.net/pipermail/graal-dev/2017-December/005141.html
      substituteInPlace $out/jre/lib/security/java.security \
        --replace file:/dev/random    file:/dev/./urandom \
        --replace NativePRNGBlocking  SHA1PRNG
      # copy static and dynamic libraries needed for static compilation
      cp -rf ${glibc}/lib/* $out/jre/lib/svm/clibraries/linux-amd64/
      cp ${glibc.static}/lib/* $out/jre/lib/svm/clibraries/linux-amd64/
      cp ${zlib.static}/lib/libz.a $out/jre/lib/svm/clibraries/linux-amd64/libz.a
    '';

    inherit (jvmci8) preFixup;
    dontStrip = true; # stripped javac crashes with "segmentaion fault"
    doInstallCheck = true;
    installCheckPhase = ''
      echo ${lib.escapeShellArg ''
               public class HelloWorld {
                 public static void main(String[] args) {
                   System.out.println("Hello World");
                 }
               }
             ''} > HelloWorld.java
      $out/bin/javac HelloWorld.java

      # run on JVM with Graal Compiler
      $out/bin/java -XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -XX:+UseJVMCICompiler HelloWorld
      $out/bin/java -XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -XX:+UseJVMCICompiler HelloWorld | fgrep 'Hello World'

      # Ahead-Of-Time compilation
      $out/bin/native-image --no-server HelloWorld
      ./helloworld
      ./helloworld | fgrep 'Hello World'

      # Ahead-Of-Time compilation with --static
      $out/bin/native-image --no-server --static HelloWorld
      ./helloworld
      ./helloworld | fgrep 'Hello World'
    '';

    enableParallelBuilding = true;
    passthru.home = graalvm8;

    meta = with stdenv.lib; {
      homepage = https://github.com/oracle/graal;
      description = "High-Performance Polyglot VM";
      license = licenses.gpl2;
      maintainers = with maintainers; [ volth hlolli ];
      platforms = [ "x86_64-linux" /*"aarch64-linux" "x86_64-darwin"*/ ];
    };
  };
}
