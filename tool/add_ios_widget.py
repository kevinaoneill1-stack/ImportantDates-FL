#!/usr/bin/env python3
"""Adds the "Upcoming Dates" widget extension (ImportantDatesWidget) to the
iOS Xcode project, for every build configuration of both flavors.

Run once from the project root:  python3 tool/add_ios_widget.py
Idempotent: does nothing when the project already has the widget target.

What it does to ios/Runner.xcodeproj/project.pbxproj:
  * new app-extension target ImportantDatesWidgetExtension (sources in
    ios/ImportantDatesWidget/), configurations based on
    Flutter/Widget-<flavor>.xcconfig, bundle id <app id>.Widgets,
    iOS 17 minimum, automatic signing with the app's team;
  * the Runner target embeds it ("Embed Foundation Extensions", placed before
    "Thin Binary" so Xcode does not report a build cycle) and depends on it;
  * Runner gets Runner/Runner.entitlements (App Group $(APP_GROUP_ID)).
See WIDGET_SETUP.md.
"""
import random
import re
import sys

PBX = 'ios/Runner.xcodeproj/project.pbxproj'
TARGET = 'ImportantDatesWidgetExtension'
DIR = 'ImportantDatesWidget'
APP_ID = 'com.kevinaoneill.ImportantDates'
TEAM = 'C62Q8V6ZP5'


def main():
    text = open(PBX).read()
    if TARGET in text:
        print('already done:', PBX)
        return
    used = set()

    def nid():
        while True:
            i = ''.join(random.choice('0123456789ABCDEF') for _ in range(24))
            if i not in text and i not in used:
                used.add(i)
                return i

    def insert_section_end(t, section, lines):
        marker = '/* End %s section */' % section
        if marker not in t:
            # Section does not exist yet: add it before XCBuildConfiguration.
            before = '/* Begin XCBuildConfiguration section */'
            return t.replace(before, '/* Begin %s section */\n%s%s\n\n%s' % (section, lines, marker, before), 1)
        return t.replace(marker, lines + marker, 1)

    def add_to_list(t, owner_pattern, key, line, after=None):
        """Adds `line` (one or more tab-indented lines) to the `key = ( ... );`
        list of the object matched by owner_pattern."""
        m = re.search(owner_pattern + r'.*?\n(\t+)%s = \(\n(.*?)(?<=\n)\1\);' % key, t, re.S)
        if not m:
            sys.exit('not found: %s / %s' % (owner_pattern, key))
        body = m.group(2)
        if after:
            am = re.search(r'^.*%s.*\n' % re.escape(after), body, re.M)
            if not am:
                sys.exit('not found in %s: %s' % (key, after))
            new_body = body[:am.end()] + line + '\n' + body[am.end():]
        else:
            new_body = body + line + '\n'
        return t[:m.start(2)] + new_body + t[m.end(2):]

    def find(pattern):
        m = re.search(pattern, text)
        if not m:
            sys.exit('not found: ' + pattern)
        return m.group(1)

    runner = find(r'([0-9A-F]{24}) /\* Runner \*/ = \{\n\t\t\tisa = PBXNativeTarget;')
    project = find(r'([0-9A-F]{24}) /\* Project object \*/ = \{')
    main_group = find(r'mainGroup = ([0-9A-F]{24});')
    products = find(r'productRefGroup = ([0-9A-F]{24})')
    runner_group = find(r'([0-9A-F]{24}) /\* Runner \*/ = \{\n\t\t\tisa = PBXGroup;')
    flutter_group = find(r'([0-9A-F]{24}) /\* Flutter \*/ = \{\n\t\t\tisa = PBXGroup;')
    runner_list = find(r'([0-9A-F]{24}) /\* Build configuration list for PBXNativeTarget "Runner" \*/ = \{')

    ids = {k: nid() for k in [
        'appex', 'swift', 'plist', 'ent', 'runner_ent', 'xc_personal', 'xc_public', 'group',
        'swift_build', 'appex_build', 'sources', 'frameworks', 'resources', 'embed', 'target',
        'proxy', 'dependency', 'config_list']}

    # File references.
    refs = (
        '\t\t%(appex)s /* %(T)s.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = %(T)s.appex; sourceTree = BUILT_PRODUCTS_DIR; };\n'
        '\t\t%(swift)s /* ImportantDatesWidget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ImportantDatesWidget.swift; sourceTree = "<group>"; };\n'
        '\t\t%(plist)s /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };\n'
        '\t\t%(ent)s /* ImportantDatesWidget.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = ImportantDatesWidget.entitlements; sourceTree = "<group>"; };\n'
        '\t\t%(runner_ent)s /* Runner.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Runner.entitlements; sourceTree = "<group>"; };\n'
        '\t\t%(xc_personal)s /* Widget-personal.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Widget-personal.xcconfig"; path = "Flutter/Widget-personal.xcconfig"; sourceTree = "<group>"; };\n'
        '\t\t%(xc_public)s /* Widget-public.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Widget-public.xcconfig"; path = "Flutter/Widget-public.xcconfig"; sourceTree = "<group>"; };\n'
    ) % dict(ids, T=TARGET)
    text = insert_section_end(text, 'PBXFileReference', refs)

    builds = (
        '\t\t%(swift_build)s /* ImportantDatesWidget.swift in Sources */ = {isa = PBXBuildFile; fileRef = %(swift)s /* ImportantDatesWidget.swift */; };\n'
        '\t\t%(appex_build)s /* %(T)s.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = %(appex)s /* %(T)s.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };\n'
    ) % dict(ids, T=TARGET)
    text = insert_section_end(text, 'PBXBuildFile', builds)

    # Groups.
    group = (
        '\t\t%(group)s /* %(D)s */ = {\n'
        '\t\t\tisa = PBXGroup;\n'
        '\t\t\tchildren = (\n'
        '\t\t\t\t%(swift)s /* ImportantDatesWidget.swift */,\n'
        '\t\t\t\t%(plist)s /* Info.plist */,\n'
        '\t\t\t\t%(ent)s /* ImportantDatesWidget.entitlements */,\n'
        '\t\t\t);\n'
        '\t\t\tpath = %(D)s;\n'
        '\t\t\tsourceTree = "<group>";\n'
        '\t\t};\n'
    ) % dict(ids, D=DIR)
    text = insert_section_end(text, 'PBXGroup', group)
    text = add_to_list(text, r'\t\t%s = \{\n\t\t\tisa = PBXGroup;' % main_group, 'children',
                       '\t\t\t\t%s /* %s */,' % (ids['group'], DIR), after='/* Runner */')
    text = add_to_list(text, r'\t\t%s /\* Products \*/ = \{' % products, 'children',
                       '\t\t\t\t%s /* %s.appex */,' % (ids['appex'], TARGET))
    text = add_to_list(text, r'\t\t%s /\* Runner \*/ = \{\n\t\t\tisa = PBXGroup;' % runner_group, 'children',
                       '\t\t\t\t%s /* Runner.entitlements */,' % ids['runner_ent'], after='/* Info.plist */')
    text = add_to_list(text, r'\t\t%s /\* Flutter \*/ = \{\n\t\t\tisa = PBXGroup;' % flutter_group, 'children',
                       '\t\t\t\t%s /* Widget-personal.xcconfig */,\n\t\t\t\t%s /* Widget-public.xcconfig */,'
                       % (ids['xc_personal'], ids['xc_public']))

    # Build phases of the extension.
    def phase(pid, isa, name, files=''):
        return ('\t\t%s /* %s */ = {\n\t\t\tisa = %s;\n\t\t\tbuildActionMask = 2147483647;\n'
                '\t\t\tfiles = (\n%s\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n'
                % (pid, name, isa, files))
    text = insert_section_end(text, 'PBXSourcesBuildPhase', phase(
        ids['sources'], 'PBXSourcesBuildPhase', 'Sources',
        '\t\t\t\t%s /* ImportantDatesWidget.swift in Sources */,\n' % ids['swift_build']))
    text = insert_section_end(text, 'PBXFrameworksBuildPhase', phase(ids['frameworks'], 'PBXFrameworksBuildPhase', 'Frameworks'))
    text = insert_section_end(text, 'PBXResourcesBuildPhase', phase(ids['resources'], 'PBXResourcesBuildPhase', 'Resources'))

    embed = (
        '\t\t%(embed)s /* Embed Foundation Extensions */ = {\n'
        '\t\t\tisa = PBXCopyFilesBuildPhase;\n'
        '\t\t\tbuildActionMask = 2147483647;\n'
        '\t\t\tdstPath = "";\n'
        '\t\t\tdstSubfolderSpec = 13;\n'
        '\t\t\tfiles = (\n'
        '\t\t\t\t%(appex_build)s /* %(T)s.appex in Embed Foundation Extensions */,\n'
        '\t\t\t);\n'
        '\t\t\tname = "Embed Foundation Extensions";\n'
        '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        '\t\t};\n'
    ) % dict(ids, T=TARGET)
    text = insert_section_end(text, 'PBXCopyFilesBuildPhase', embed)

    # Target, dependency, project.
    target = (
        '\t\t%(target)s /* %(T)s */ = {\n'
        '\t\t\tisa = PBXNativeTarget;\n'
        '\t\t\tbuildConfigurationList = %(config_list)s /* Build configuration list for PBXNativeTarget "%(T)s" */;\n'
        '\t\t\tbuildPhases = (\n'
        '\t\t\t\t%(sources)s /* Sources */,\n'
        '\t\t\t\t%(frameworks)s /* Frameworks */,\n'
        '\t\t\t\t%(resources)s /* Resources */,\n'
        '\t\t\t);\n'
        '\t\t\tbuildRules = (\n\t\t\t);\n'
        '\t\t\tdependencies = (\n\t\t\t);\n'
        '\t\t\tname = %(T)s;\n'
        '\t\t\tproductName = %(T)s;\n'
        '\t\t\tproductReference = %(appex)s /* %(T)s.appex */;\n'
        '\t\t\tproductType = "com.apple.product-type.app-extension";\n'
        '\t\t};\n'
    ) % dict(ids, T=TARGET)
    text = insert_section_end(text, 'PBXNativeTarget', target)

    proxy = (
        '\t\t%(proxy)s /* PBXContainerItemProxy */ = {\n'
        '\t\t\tisa = PBXContainerItemProxy;\n'
        '\t\t\tcontainerPortal = %(project)s /* Project object */;\n'
        '\t\t\tproxyType = 1;\n'
        '\t\t\tremoteGlobalIDString = %(target)s;\n'
        '\t\t\tremoteInfo = %(T)s;\n'
        '\t\t};\n'
    ) % dict(ids, T=TARGET, project=project)
    text = insert_section_end(text, 'PBXContainerItemProxy', proxy)
    dep = (
        '\t\t%(dependency)s /* PBXTargetDependency */ = {\n'
        '\t\t\tisa = PBXTargetDependency;\n'
        '\t\t\ttarget = %(target)s /* %(T)s */;\n'
        '\t\t\ttargetProxy = %(proxy)s /* PBXContainerItemProxy */;\n'
        '\t\t};\n'
    ) % dict(ids, T=TARGET)
    text = insert_section_end(text, 'PBXTargetDependency', dep)

    runner_pat = r'\t\t%s /\* Runner \*/ = \{\n\t\t\tisa = PBXNativeTarget;' % runner
    text = add_to_list(text, runner_pat, 'buildPhases',
                       '\t\t\t\t%s /* Embed Foundation Extensions */,' % ids['embed'], after='/* Embed Frameworks */')
    text = add_to_list(text, runner_pat, 'dependencies',
                       '\t\t\t\t%s /* PBXTargetDependency */,' % ids['dependency'])

    proj_pat = r'\t\t%s /\* Project object \*/ = \{' % project
    text = add_to_list(text, proj_pat, 'targets', '\t\t\t\t%s /* %s */,' % (ids['target'], TARGET))
    text = text.replace('\t\t\t\tTargetAttributes = {\n',
                        '\t\t\t\tTargetAttributes = {\n\t\t\t\t\t%s = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;\n\t\t\t\t\t};\n'
                        % ids['target'], 1)

    # Build configurations: one per Runner configuration, same names.
    list_m = re.search(r'\t\t%s /\* Build configuration list for PBXNativeTarget "Runner" \*/ = \{\n'
                       r'\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = \(\n(.*?)\t\t\t\);' % runner_list, text, re.S)
    runner_configs = re.findall(r'\t\t\t\t([0-9A-F]{24}) /\* ([^*]+?) \*/,\n', list_m.group(1))
    configs = ''
    entries = ''
    for cid, name in runner_configs:
        flavor = 'personal' if name.endswith('-personal') else 'public'
        debug = name.startswith('Debug')
        bundle = APP_ID + ('.personal' if flavor == 'personal' else '') + '.Widgets'
        xc = ids['xc_personal'] if flavor == 'personal' else ids['xc_public']
        settings = [
            ('APPLICATION_EXTENSION_API_ONLY', 'YES'),
            ('CODE_SIGN_ENTITLEMENTS', '%s/ImportantDatesWidget.entitlements' % DIR),
            ('CODE_SIGN_STYLE', 'Automatic'),
            ('CURRENT_PROJECT_VERSION', '"$(FLUTTER_BUILD_NUMBER)"'),
            ('DEVELOPMENT_TEAM', TEAM),
            ('GENERATE_INFOPLIST_FILE', 'YES'),
            ('INFOPLIST_FILE', '%s/Info.plist' % DIR),
            ('INFOPLIST_KEY_CFBundleDisplayName', '"$(APP_DISPLAY_NAME)"'),
            ('INFOPLIST_KEY_NSHumanReadableCopyright', '""'),
            ('IPHONEOS_DEPLOYMENT_TARGET', '17.0'),
            ('LD_RUNPATH_SEARCH_PATHS', '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t\t"@executable_path/../../Frameworks",\n\t\t\t\t)'),
            ('MARKETING_VERSION', '"$(FLUTTER_BUILD_NAME)"'),
            ('PRODUCT_BUNDLE_IDENTIFIER', bundle),
            ('PRODUCT_NAME', '"$(TARGET_NAME)"'),
            ('SKIP_INSTALL', 'YES'),
            ('SWIFT_EMIT_LOC_STRINGS', 'YES'),
            ('SWIFT_VERSION', '5.0'),
            ('TARGETED_DEVICE_FAMILY', '"1,2"'),
        ]
        if debug:
            settings += [
                ('DEBUG_INFORMATION_FORMAT', 'dwarf'),
                ('SWIFT_ACTIVE_COMPILATION_CONDITIONS', '"DEBUG $(inherited)"'),
                ('SWIFT_OPTIMIZATION_LEVEL', '"-Onone"'),
            ]
        else:
            settings += [('SWIFT_COMPILATION_MODE', 'wholemodule'), ('SWIFT_OPTIMIZATION_LEVEL', '"-O"')]
        settings.sort()
        new = nid()
        quoted = '"%s"' % name if '-' in name else name
        configs += '\t\t%s /* %s */ = {\n\t\t\tisa = XCBuildConfiguration;\n' % (new, name)
        configs += '\t\t\tbaseConfigurationReference = %s /* Widget-%s.xcconfig */;\n' % (xc, flavor)
        configs += '\t\t\tbuildSettings = {\n'
        configs += ''.join('\t\t\t\t%s = %s;\n' % kv for kv in settings)
        configs += '\t\t\t};\n\t\t\tname = %s;\n\t\t};\n' % quoted
        entries += '\t\t\t\t%s /* %s */,\n' % (new, name)

    # Runner: entitlements with the App Group.
    for cid, name in runner_configs:
        bm = re.search(r'\t\t%s /\* [^*]+ \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\tbuildSettings = \{\n' % cid, text, re.S)
        if not bm:
            sys.exit('Runner configuration %s not found' % name)
        text = text[:bm.end()] + '\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n' + text[bm.end():]

    text = insert_section_end(text, 'XCBuildConfiguration', configs)
    clist = (
        '\t\t%s /* Build configuration list for PBXNativeTarget "%s" */ = {\n'
        '\t\t\tisa = XCConfigurationList;\n'
        '\t\t\tbuildConfigurations = (\n%s\t\t\t);\n'
        '\t\t\tdefaultConfigurationIsVisible = 0;\n'
        '\t\t\tdefaultConfigurationName = Release;\n'
        '\t\t};\n'
    ) % (ids['config_list'], TARGET, entries)
    text = insert_section_end(text, 'XCConfigurationList', clist)

    open(PBX, 'w').write(text)
    print('added %s to %s' % (TARGET, PBX))


if __name__ == '__main__':
    random.seed()
    main()
