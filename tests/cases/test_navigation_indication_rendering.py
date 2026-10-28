"""R-NAV-013: actual write-only native declarations and preserved typography."""
import subprocess
import json
import unittest
from host import Host, ROOT
STYLE_BASELINE=json.loads((ROOT/'docs/overhaul/navigation-execution/side-indication-before.json').read_text(
    encoding='utf-8'))['head']


def declarations(path,baseline=False):
    h=Host()
    h.execute('function SetScale()end;function MakeMaterial(path,color)return path or color end;'
        'function MakeFont(name)return name end;MILLYRADIANS=1;FOV=1;'
        'h_clip_relations={REWRITE_LEVEL=1,INCREASE_IF_LEVEL=2,COMPARE=3}')
    actual=h.env.dofile
    h.env.dofile=lambda p:None if str(p)=='common/elements_defs.lua' else actual(p)
    if baseline:
        source=subprocess.check_output(['git','show',STYLE_BASELINE+':Cockpit/Scripts/'+path],cwd=ROOT).decode('utf-8-sig')
        factory=h.execute(source)
    else:
        factory=h.load(path)
    if path.startswith('MFD_COMMON/'):
        factory('LMFD_ADI_PAGE')
    return [value for _,value in h.state.elements.items() if value['added']]


def normalized(value):
    if hasattr(value,'items'):
        return tuple(sorted((str(k),normalized(v)) for k,v in value.items()))
    return value


def shown(spec,flag,value):
    for _,control in spec['controllers'].items():
        kind=control[1]
        if kind=='parameter_in_range':
            parameter=spec['element_params'][control[2]+1]
            observed=value if parameter==flag else 1
            if not control[3]<=observed<=control[4]:
                return False
    return True


class NavigationIndicationRendering(unittest.TestCase):
    def test_numeric_and_unavailable_nodes_are_exclusive_and_keep_their_style(self):
        properties=['material','init_pos','init_rot','alignment','stringdefs','level',
                    'h_clip_relation','collimated','vertices','indices','tex_coords']
        for path,count in [('MFD_COMMON/adi_page.lua',4),('UFD_LEFT/base_page.lua',7),
                           ('UFD_RIGHT/base_page.lua',7)]:
            current=declarations(path);original=declarations(path,baseline=True)
            nodes=[x for x in current if x['formats'] and x['element_params']
                and any(str(p).startswith('F22_SIDE_') for _,p in x['element_params'].items())]
            self.assertEqual(len(nodes),count,path)
            for number in nodes:
                params=number['element_params']
                flag=next(str(p) for _,p in params.items() if str(p).startswith('F22_SIDE_'))
                missing=next(x for x in current if x['name']==number['name']+'_'+flag+'_UNAVAILABLE')
                self.assertEqual(missing['value'],'---')
                self.assertNotIn('%s',str(number['formats'][1]))
                for value in [0,1]:
                    self.assertEqual(shown(number,flag,value),value==1)
                    self.assertEqual(shown(missing,flag,value),value==0)
                value_key=params[2]
                if value_key=='F22_SFG_HEADING':value_key='NAV'
                candidates=[x for x in original if x['formats'] and x['element_params']
                    and x['element_params'][2]==value_key]
                # The retained right G block is the existing larger, second block.
                old=max(candidates,key=lambda item:float(item['stringdefs'][1]))
                for prop in properties:
                    self.assertEqual(normalized(number[prop]),normalized(old[prop]),(path,value_key,prop))

    def test_right_side_has_one_current_g_graph(self):
        nodes=declarations('UFD_RIGHT/base_page.lua')
        numeric=[x for x in nodes if x['formats'] and x['element_params']
                 and x['element_params'][2]=='GFORCE']
        self.assertEqual(len(numeric),1)


if __name__=='__main__':
    unittest.main()
