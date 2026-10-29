"""Read installed navigation PE interfaces; never load/execute or modify a DCS DLL.

Raw decompilation stays in the requested external analysis directory. Optional
IDA RPC reads use the existing local JSON-RPC plugin and do not patch/type bytes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import urllib.request

import capstone
import pefile

ROOT=Path(__file__).resolve().parents[1]
LIMIT=128*1024*1024
CLOCK='?GetModelTime@wTime@@SANXZ'
VARIATION='?get_mag_decl@magvar@@YAMMM@Z'
COORDINATES='?LatLon@MapCoords@MapCoordsSpace@@SAXNNAEAN0@Z'
PARAMETERS=['ed_cockpit_get_parameter_handle','ed_cockpit_update_parameter_with_number',
    'ed_cockpit_update_parameter_with_string','ed_cockpit_parameter_value_to_number',
    'ed_cockpit_parameter_value_to_string','ed_cockpit_compare_parameters']
TABLES=['??_7avTACAN@cockpit@@6BccContextRelatedObject@1@@',
    '??_7avILS@cockpit@@6BccContextRelatedObject@1@@',
    '??_7avSimpleElectricSystem@cockpit@@6BccContextRelatedObject@1@@']
INTERNAL={'loc_update':'?update_LOC@avILS@cockpit@@IEAAXXZ',
    'gs_update':'?update_Marker@avILS@cockpit@@IEAAXXZ',
    'tacan_update':'?updateRangeBearing@avTACAN@cockpit@@MEAAXXZ',
    'activity':'?make_default_activity@avDevice@cockpit@@IEAAXN@Z',
    'ils_constructor':'??0avILS@cockpit@@QEAA@XZ',
    'electrical_constructor':'??0avSimpleElectricSystem@cockpit@@QEAA@XZ'}


def digest(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()


def binding_names():
    source=(ROOT/'EFM/source/NativeNavigation.cpp').read_text(encoding='utf-8')
    entries=re.findall(r'BIND\(\s*(\w+),\s*\w+,\s*((?:"[^"]*"\s*)+)\)',source)
    return {field:''.join(re.findall(r'"([^"]*)"',strings)) for field,strings in entries}


def inspect_pe(path,wanted):
    if path.stat().st_size>LIMIT:raise ValueError('PE exceeds128MiB analysis bound')
    pe=pefile.PE(str(path),fast_load=True)
    if pe.FILE_HEADER.Machine!=0x8664:raise ValueError('Expected x64 PE')
    pe.parse_data_directories(directories=[0,1])
    exports={s.name.decode('ascii'):s for s in pe.DIRECTORY_ENTRY_EXPORT.symbols if s.name}
    report={'path':str(path),'sha256':digest(path),'timestamp':hex(pe.FILE_HEADER.TimeDateStamp),
        'image_size':hex(pe.OPTIONAL_HEADER.SizeOfImage),'exports':{},'allocator_imports':[]}
    decoder=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64)
    for name in wanted:
        symbol=exports.get(name)
        if symbol is None:report['exports'][name]={'present':False};continue
        entry={'present':True,'rva':hex(symbol.address),
            'forwarder':symbol.forwarder.decode('ascii') if symbol.forwarder else None}
        section=pe.get_section_by_rva(symbol.address)
        entry['executable_section']=bool(section and section.Characteristics&0x20000000)
        if entry['executable_section'] and not symbol.forwarder:
            data=pe.get_data(symbol.address,64)
            entry['prefix_bytes_available']=len(data)
            entry['first64_sha256']=hashlib.sha256(data).hexdigest() if len(data)==64 else None
            entry['prefix_instructions']=[f'{i.mnemonic} {i.op_str}' for i in decoder.disasm(
                data,pe.OPTIONAL_HEADER.ImageBase+symbol.address,count=8)]
        report['exports'][name]=entry
    for descriptor in pe.DIRECTORY_ENTRY_IMPORT:
        for symbol in descriptor.imports:
            if symbol.name in [b'malloc',b'free']:
                report['allocator_imports'].append({'module':descriptor.dll.decode('ascii'),
                    'name':symbol.name.decode('ascii'),
                    'iat_rva':hex(symbol.address-pe.OPTIONAL_HEADER.ImageBase)})
    return report


def rpc(port,method,params):
    if not 1024<=port<=65535:raise ValueError('Invalid local port')
    request=urllib.request.Request(f'http://127.0.0.1:{port}/mcp',headers={'Content-Type':'application/json'},
        data=json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode())
    with urllib.request.urlopen(request,timeout=30) as response:
        raw=response.read(4*1024*1024+1)
    if len(raw)>4*1024*1024:raise ValueError('RPC result exceeds4MiB bound')
    result=json.loads(raw)
    if 'error'in result:raise RuntimeError(str(result['error']))
    return result['result']


def normalized(text):
    return re.sub(r'180[0-9a-fA-F]{6,}','ADDR',re.sub(r'/\*.*?\*/','',text)).strip()


def compare_ida(output,previous,current,names,expected_hash):
    metadata={label:rpc(port,'get_metadata',{}) for label,port in [('previous',previous),('current',current)]}
    if metadata['current']['sha256']!=expected_hash:raise ValueError('IDA input differs from installed DLL')
    previous_input=Path(metadata['previous']['path'])
    if digest(previous_input)!=metadata['previous']['sha256']:raise ValueError('Previous IDA input hash mismatch')
    (output/'ida-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    comparisons={}
    for key,name in names.items():
        texts={};entries={}
        for label,port in [('previous',previous),('current',current)]:
            function=rpc(port,'get_function_by_name',{'name':name})
            text=rpc(port,'decompile_function',{'address':function['address']})
            path=output/f'{label}-{key}.json'
            path.write_text(json.dumps({'function':function,'decompilation':text},indent=2)+'\n',encoding='utf-8')
            entries[label]={'address':function['address'],'raw_sha256':digest(path)};texts[label]=text
        comparisons[key]={'symbol':name,'entries':entries,
            'normalized_pseudocode_equal':normalized(texts['previous'])==normalized(texts['current'])}
    return comparisons


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dcs-bin',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--current-ida-port',type=int)
    parser.add_argument('--previous-ida-port',type=int)
    args=parser.parse_args();output=args.output.resolve()
    if output==ROOT or ROOT in output.parents:parser.error('Raw analysis belongs outside the checkout')
    output.mkdir(parents=True,exist_ok=True)
    names=binding_names()
    report={'CockpitBase.dll':inspect_pe(args.dcs_bin/'CockpitBase.dll',list(names.values())+TABLES+PARAMETERS),
        'World.dll':inspect_pe(args.dcs_bin/'World.dll',[CLOCK]),
        'WorldGeneral.dll':inspect_pe(args.dcs_bin/'WorldGeneral.dll',[VARIATION,COORDINATES])}
    if args.current_ida_port and args.previous_ida_port:
        parameter_names={f'parameter_{index}':name for index,name in enumerate(PARAMETERS)}
        report['IDA_comparison']=compare_ida(output,args.previous_ida_port,args.current_ida_port,
            names|INTERNAL|parameter_names,report['CockpitBase.dll']['sha256'])
    report['limits']='Export presence/pseudocode comparisons do not prove host concurrency, lifecycle, RF or audio.'
    (output/'REPORT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'DLLs':3,'bindings':len(names),'report':str(output/'REPORT.json')}))


if __name__=='__main__':main()
