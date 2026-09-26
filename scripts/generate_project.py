#!/usr/bin/env python3
"""Generate the small native project without third-party build dependencies."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "LookFar.xcodeproj"
REVENUECAT_VERSION = "5.90.2"
objects = {}

def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def add(object_name, isa, **values):
    key = uid(object_name)
    objects[key] = {"isa": isa, **values}
    return key

def file(path, kind):
    return add("file:" + path, "PBXFileReference", lastKnownFileType=kind, path=path, sourceTree="SOURCE_ROOT")

def buildfile(target, ref, **extra):
    return add("build:" + target + ref, "PBXBuildFile", fileRef=ref, **extra)

refs = {}
for folder in ("App", "Core", "Shared", "Extensions", "UITests"):
    for path in sorted((ROOT / folder).glob("*.swift")):
        relative = str(path.relative_to(ROOT))
        refs[relative] = file(relative, "sourcecode.swift")
assets = file("App/Assets.xcassets", "folder.assetcatalog")
storekit = file("Config/LookFar.storekit", "text")
privacy = file("Config/PrivacyInfo.xcprivacy", "text.xml")
revenuecat_config = file("Config/RevenueCat.xcconfig", "text.xcconfig")
revenuecat_package = add(
    "package:revenuecat", "XCRemoteSwiftPackageReference",
    repositoryURL="https://github.com/RevenueCat/purchases-ios-spm.git",
    requirement={"kind": "exactVersion", "version": REVENUECAT_VERSION},
)
revenuecat_product = add(
    "product:revenuecat", "XCSwiftPackageProductDependency",
    package=revenuecat_package, productName="RevenueCat",
)
extra = [file(str(p.relative_to(ROOT)), "text.plist.xml") for p in sorted((ROOT / "Config").glob("*.plist"))]
extra += [file(str(p.relative_to(ROOT)), "text.plist.entitlements") for p in sorted((ROOT / "Config").glob("*.entitlements"))]
products = {}
target_ids = {name: uid("target:" + name) for name in ("LookFar", "ActivityMonitor", "ShieldConfiguration", "ShieldAction", "ScreenTimeReport", "LookFarUITests")}

base = {
    "CLANG_ENABLE_MODULES": "YES", "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "26.5",
    "SWIFT_VERSION": "5.0", "TARGETED_DEVICE_FAMILY": "1", "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "VRT5976586",
    "MARKETING_VERSION": "0.1.0", "CURRENT_PROJECT_VERSION": "1", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "SWIFT_EMIT_LOC_STRINGS": "YES", "GENERATE_INFOPLIST_FILE": "YES", "PRODUCT_NAME": "$(TARGET_NAME)",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
    "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO", "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO"
}

def configlist(name, settings, base_config=None):
    configs = []
    for mode in ("Debug", "Release"):
        options = {**base, **settings}
        options["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if mode == "Debug" else "-O"
        options["DEBUG_INFORMATION_FORMAT"] = "dwarf" if mode == "Debug" else "dwarf-with-dsym"
        if mode == "Debug":
            options["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
            options["ENABLE_TESTABILITY"] = "YES"
            options["ONLY_ACTIVE_ARCH"] = "YES"
        configuration = {"buildSettings": options, "name": mode}
        if base_config:
            configuration["baseConfigurationReference"] = base_config
        configs.append(add(name + mode, "XCBuildConfiguration", **configuration))
    return add(name + "configs", "XCConfigurationList", buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName="Release")

def dependency(name, target):
    proxy = add(name + "proxy", "PBXContainerItemProxy", containerPortal=uid("project"), proxyType=1,
                remoteGlobalIDString=target_ids[target], remoteInfo=target)
    return add(name + "dependency", "PBXTargetDependency", target=target_ids[target], targetProxy=proxy)

for name, identifier in target_ids.items():
    main = name == "LookFar"
    test = name == "LookFarUITests"
    report = name == "ScreenTimeReport"
    extension = not main and not test
    suffix = ".app" if main else ".xctest" if test else ".appex"
    product = add(name + "product", "PBXFileReference", explicitFileType="wrapper.application" if main else "wrapper.cfbundle",
                  includeInIndex=0, path=name + suffix, sourceTree="BUILT_PRODUCTS_DIR")
    products[name] = product
    if main:
        sources = [ref for path, ref in refs.items() if path.startswith(("App/", "Core/", "Shared/"))]
    elif test:
        sources = [ref for path, ref in refs.items() if path.startswith("UITests/")]
        sources.append(refs["Shared/ScreenTimeSupport.swift"])
        sources.append(refs["Core/UsageGapTracker.swift"])
    elif report:
        sources = [refs[path] for path in ("Extensions/ScreenTimeReport.swift", "Shared/ScreenTimeReportContent.swift", "App/Theme.swift")]
    else:
        sources = [refs["Shared/ScreenTimeSupport.swift"], refs["Core/UsageGapTracker.swift"], refs["Extensions/" + name + ".swift"]]
    source_phase = add(name + "sources", "PBXSourcesBuildPhase", buildActionMask=2147483647,
                       files=[buildfile(name, ref) for ref in sources], runOnlyForDeploymentPostprocessing=0)
    resources = [assets, privacy] if main else [] if test else [privacy]
    resource_phase = add(name + "resources", "PBXResourcesBuildPhase", buildActionMask=2147483647,
                         files=[buildfile(name, ref) for ref in resources], runOnlyForDeploymentPostprocessing=0)
    frameworks = [add("build:revenuecat", "PBXBuildFile", productRef=revenuecat_product)] if main else []
    framework_phase = add(name + "frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=frameworks, runOnlyForDeploymentPostprocessing=0)
    settings = {"PRODUCT_BUNDLE_IDENTIFIER": "dev.local.lookfar" + ("" if main else "." + name.lower()),
                "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"]}
    if main:
        settings.update({"CODE_SIGN_ENTITLEMENTS": "Config/ScreenTime.entitlements", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                         "INFOPLIST_FILE": "Config/LookFar-Info.plist",
                         "INFOPLIST_KEY_CFBundleDisplayName": "Look Far", "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.healthcare-fitness",
                         "INFOPLIST_KEY_UILaunchScreen_Generation": "YES", "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
                         "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait"})
    elif extension:
        settings.update({"CODE_SIGN_ENTITLEMENTS": "Config/ScreenTime.entitlements", "APPLICATION_EXTENSION_API_ONLY": "YES", "SKIP_INSTALL": "YES",
                         "INFOPLIST_FILE": "Config/" + name + "-Info.plist",
                         "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]})
        if report:
            settings["CODE_SIGN_ENTITLEMENTS"] = "Config/ScreenTimeReport.entitlements"
    else:
        settings["TEST_TARGET_NAME"] = "LookFar"
    deps = [dependency(name + "toapp", "LookFar")] if test else []
    objects[identifier] = {"isa": "PBXNativeTarget", "buildConfigurationList": configlist(name, settings, revenuecat_config if main else None),
                           "buildPhases": [source_phase, framework_phase, resource_phase], "buildRules": [], "dependencies": deps,
                           "name": name, "productName": name, "productReference": product,
                           "productType": "com.apple.product-type.application" if main else "com.apple.product-type.bundle.ui-testing" if test else "com.apple.product-type.extensionkit-extension" if report else "com.apple.product-type.app-extension"}
    if main:
        objects[identifier]["packageProductDependencies"] = [revenuecat_product]

extensions = ["ActivityMonitor", "ShieldConfiguration", "ShieldAction"]
embed = add("embed", "PBXCopyFilesBuildPhase", buildActionMask=2147483647, dstPath="", dstSubfolderSpec=13,
            files=[buildfile("embed", products[n], settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]}) for n in extensions],
            name="Embed App Extensions", runOnlyForDeploymentPostprocessing=0)
objects[target_ids["LookFar"]]["buildPhases"].append(embed)
embed_report = add("embed-report", "PBXCopyFilesBuildPhase", buildActionMask=2147483647,
                   dstPath="$(CONTENTS_FOLDER_PATH)/Extensions", dstSubfolderSpec=16,
                   files=[buildfile("embed", products["ScreenTimeReport"], settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})],
                   name="Embed Screen Time Report", runOnlyForDeploymentPostprocessing=0)
objects[target_ids["LookFar"]]["buildPhases"].append(embed_report)
objects[target_ids["LookFar"]]["dependencies"] = [dependency("app" + n, n) for n in extensions + ["ScreenTimeReport"]]
product_group = add("products", "PBXGroup", children=list(products.values()), name="Products", sourceTree="<group>")
source_group = add("sources", "PBXGroup", children=list(refs.values()) + [assets], name="Sources", sourceTree="<group>")
config_group = add("config", "PBXGroup", children=[storekit, privacy, revenuecat_config] + extra, name="Configuration", sourceTree="<group>")
root_group = add("root", "PBXGroup", children=[source_group, config_group, product_group], sourceTree="<group>")
add("project", "PBXProject", attributes={
        "BuildIndependentTargetsInParallel": "YES", "LastUpgradeCheck": "2660",
        "TargetAttributes": {target_ids["LookFar"]: {"SystemCapabilities": {"com.apple.InAppPurchase": {"enabled": 1}}}},
    },
    buildConfigurationList=configlist("project", {}), compatibilityVersion="Xcode 14.0", developmentRegion="en",
    hasScannedForEncodings=0, knownRegions=["en", "Base"], mainGroup=root_group, productRefGroup=product_group,
    projectDirPath="", projectRoot="", targets=list(target_ids.values()), packageReferences=[revenuecat_package])

def serialize(value, indent=0):
    if isinstance(value, dict):
        return "{\n" + "\n".join("\t" * (indent + 1) + json.dumps(str(k)) + " = " + serialize(v, indent + 1) + ";" for k, v in value.items()) + "\n" + "\t" * indent + "}"
    if isinstance(value, list):
        return "(" + ", ".join(serialize(v, indent) for v in value) + ")"
    return str(value) if isinstance(value, int) else json.dumps(value)

PROJECT.mkdir(exist_ok=True)
(PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + serialize({"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": objects, "rootObject": uid("project")}) + "\n")
scheme_dir = PROJECT / "xcshareddata/xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
def reference(name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids[name]}" BuildableName="{name}{".app" if name == "LookFar" else ".xctest"}" BlueprintName="{name}" ReferencedContainer="container:LookFar.xcodeproj"/>'

(scheme_dir / "LookFar.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference("LookFar")}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
<Testables><TestableReference skipped="NO">{reference("LookFarUITests")}</TestableReference></Testables>
</TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
<BuildableProductRunnable runnableDebuggingMode="0">{reference("LookFar")}</BuildableProductRunnable>
</LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference("LookFar")}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(f"Generated {PROJECT}")
