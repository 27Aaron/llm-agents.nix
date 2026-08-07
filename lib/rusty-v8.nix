{
  lib,
  stdenv,
  fetchurl,
}:

lib.makeOverridable (
  {
    version,
    hashes,
    # Prebuilt flavor: "release" (denoland's default) or a feature-suffixed
    # profile like "ptrcomp_sandbox_release" (openai's codex builds).
    profile ? "release",
    baseUrl ? "https://github.com/denoland/rusty_v8/releases/download/v${version}",
    # rusty_v8 >= 150 also needs the pre-generated src_binding_*.rs
    # (RUSTY_V8_SRC_BINDING_PATH).  Exposed as passthru.srcBinding.
    srcBindingHashes ? null,
  }:

  let
    target = stdenv.hostPlatform.rust.rustcTarget;
  in
  fetchurl {
    name = "librusty_v8-${version}";
    url = "${baseUrl}/librusty_v8_${profile}_${target}.a.gz";
    hash = hashes.${stdenv.hostPlatform.system};
    meta.sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    passthru = lib.optionalAttrs (srcBindingHashes != null) {
      srcBinding = fetchurl {
        name = "src_binding-${version}.rs";
        url = "${baseUrl}/src_binding_${profile}_${target}.rs";
        hash = srcBindingHashes.${stdenv.hostPlatform.system};
      };
    };
  }
)
