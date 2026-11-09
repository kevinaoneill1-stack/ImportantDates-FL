#!/usr/bin/env python3
"""Adds personal/public flavor build configurations to the iOS and macOS
Xcode projects of ImportantDates_FL. Run once from the project root.
Idempotent: does nothing for a project that already has Debug-personal."""
import os
import random
import re
import sys

FLAVORS = ['personal', 'public']
MODES = ['Debug', 'Release', 'Profile']
IOS_ID = 'com.kevinaoneill.ImportantDates'

def new_id(text, used):
    while True:
        i = ''.join(random.choice('0123456789ABCDEF') for _ in range(24))
        if i not in text and i not in used:
            used.add(i)
            return i

def section(text, name):
    m = re.search(r'/\* Begin %s section \*/\n(.*?)/\* End %s section \*/' % (name, name), text, re.S)
    return m

def config_blocks(text):
    sec = section(text, 'XCBuildConfiguration')
    blocks = {}
    for m in re.finditer(r'\t\t([0-9A-F]{24}) /\* ([^*]+) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};\n', sec.group(1), re.S):
        blocks[m.group(1)] = (m.group(2), m.group(0))
    return sec, blocks

def flavorize(path, customize, new_files):
    text = open(path).read()
    if 'Debug-personal' in text:
        print('already done:', path)
        return
    used = set()
    # New file references (name -> id), added to the given group.
    file_ids = {}
    ref_lines = ''
    group_lines = {}
    for name, (relpath, group_id, after_child) in new_files.items():
        fid = new_id(text, used)
        file_ids[name] = fid
        if '/' in relpath:
            ref_lines += '\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "%s"; path = "%s"; sourceTree = "<group>"; };\n' % (fid, name, name, relpath)
        else:
            ref_lines += '\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = "%s"; sourceTree = "<group>"; };\n' % (fid, name, relpath)
        group_lines.setdefault((group_id, after_child), []).append('\t\t\t\t%s /* %s */,\n' % (fid, name))
    text = text.replace('/* End PBXFileReference section */', ref_lines + '/* End PBXFileReference section */', 1)
    for (group_id, after_child), lines in group_lines.items():
        gm = re.search(r'\t\t%s /\*[^*]*\*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n(.*?)\t\t\t\);' % group_id, text, re.S)
        if not gm:
            sys.exit('group %s not found in %s' % (group_id, path))
        children = gm.group(1)
        anchor = re.search(r'\t\t\t\t%s /\*[^*]*\*/,\n' % after_child, children)
        if not anchor:
            sys.exit('child %s not found in group %s' % (after_child, group_id))
        new_children = children[:anchor.end()] + ''.join(lines) + children[anchor.end():]
        text = text[:gm.start(1)] + new_children + text[gm.end(1):]

    sec, blocks = config_blocks(text)
    new_blocks = ''
    list_sec = section(text, 'XCConfigurationList')
    new_list_sec = list_sec.group(1)
    for lm in re.finditer(r'\t\t([0-9A-F]{24}) /\* (Build configuration list for [^*]+) \*/ = \{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = \(\n(.*?)\t\t\t\);', list_sec.group(1), re.S):
        list_name = lm.group(2)
        entries = lm.group(3)
        additions = ''
        for em in re.finditer(r'\t\t\t\t([0-9A-F]{24}) /\* (\w+) \*/,\n', entries):
            cid, mode = em.group(1), em.group(2)
            if mode not in MODES:
                continue
            _, block = blocks[cid]
            for flavor in FLAVORS:
                name = '%s-%s' % (mode, flavor)
                nid = new_id(text + new_blocks, used)
                b = block.replace('%s /* %s */ = {' % (cid, mode), '%s /* %s */ = {' % (nid, name), 1)
                b = b.replace('\t\t\tname = %s;\n' % mode, '\t\t\tname = "%s";\n' % name)
                b = customize(list_name, mode, flavor, b, file_ids)
                new_blocks += b
                additions += '\t\t\t\t%s /* %s */,\n' % (nid, name)
        if additions:
            new_entries = entries + additions
            new_list_sec = new_list_sec.replace(lm.group(0), lm.group(0).replace(entries, new_entries, 1), 1)
    text = text.replace(sec.group(1), sec.group(1) + new_blocks, 1)
    list_sec = section(text, 'XCConfigurationList')
    text = text.replace(list_sec.group(1), new_list_sec, 1)
    open(path, 'w').write(text)
    print('flavorized:', path)

def set_setting(block, key, value):
    pat = re.compile(r'(\t\t\t\t%s = )[^;]*;' % key)
    if pat.search(block):
        return pat.sub(lambda m: m.group(1) + value + ';', block)
    return block.replace('\t\t\tbuildSettings = {\n', '\t\t\tbuildSettings = {\n\t\t\t\t%s = %s;\n' % (key, value), 1)

def set_base(block, fid, name):
    pat = re.compile(r'\t\t\tbaseConfigurationReference = [0-9A-F]{24} /\* [^*]+ \*/;\n')
    line = '\t\t\tbaseConfigurationReference = %s /* %s */;\n' % (fid, name) if fid else ''
    if pat.search(block):
        return pat.sub(line, block)
    return block.replace('\t\t\tisa = XCBuildConfiguration;\n', '\t\t\tisa = XCBuildConfiguration;\n' + line, 1)

def bundle_id(flavor):
    return IOS_ID + ('.personal' if flavor == 'personal' else '')

def ios_customize(list_name, mode, flavor, b, file_ids):
    if '"Runner"' in list_name and 'PBXNativeTarget' in list_name:
        name = '%s-%s.xcconfig' % (mode, flavor)
        b = set_base(b, file_ids[name], name)
        b = set_setting(b, 'PRODUCT_BUNDLE_IDENTIFIER', bundle_id(flavor))
    elif '"RunnerTests"' in list_name:
        b = set_base(b, None, None)  # CocoaPods sets Pods-RunnerTests.<config>.xcconfig
    return b

def mac_customize(list_name, mode, flavor, b, file_ids):
    if '"Runner"' in list_name and 'PBXNativeTarget' in list_name and flavor == 'personal':
        b = set_base(b, file_ids['AppInfo-personal.xcconfig'], 'AppInfo-personal.xcconfig')
    return b

def main():
    ios = 'ios/Runner.xcodeproj/project.pbxproj'
    ios_text = open(ios).read()
    flutter_group = re.search(r'\t\t([0-9A-F]{24}) /\* Flutter \*/ = \{\n\t\t\tisa = PBXGroup;', ios_text).group(1)
    gen_id = re.search(r'([0-9A-F]{24}) /\* Generated\.xcconfig \*/ = \{isa = PBXFileReference', ios_text).group(1)
    ios_files = {}
    for flavor in FLAVORS:
        ios_files['Flavor-%s.xcconfig' % flavor] = ('Flutter/Flavor-%s.xcconfig' % flavor, flutter_group, gen_id)
        for mode in MODES:
            n = '%s-%s.xcconfig' % (mode, flavor)
            ios_files[n] = ('Flutter/' + n, flutter_group, gen_id)
    flavorize(ios, ios_customize, ios_files)

    mac = 'macos/Runner.xcodeproj/project.pbxproj'
    mac_text = open(mac).read()
    appinfo_id = re.search(r'([0-9A-F]{24}) /\* AppInfo\.xcconfig \*/ = \{isa = PBXFileReference', mac_text).group(1)
    configs_group = re.search(r'\t\t([0-9A-F]{24}) /\* Configs \*/ = \{\n\t\t\tisa = PBXGroup;', mac_text).group(1)
    flavorize(mac, mac_customize, {'AppInfo-personal.xcconfig': ('AppInfo-personal.xcconfig', configs_group, appinfo_id)})

if __name__ == '__main__':
    random.seed()
    main()
