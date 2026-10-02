<?php
namespace App\Services;
use App\Models\Fixture;
class MarketCatalog {
    // API-Football pre-match bet IDs. Only regulation-time markets modeled by this service.
    public static function map(int $bet,string $value): ?array {
        $v=strtolower(trim($value));
        if($bet===1 && isset(['home'=>1,'draw'=>1,'away'=>1][$v])) return ['1x2',$v];
        if($bet===12 && isset(['home/draw'=>'home_draw','home/away'=>'home_away','draw/away'=>'draw_away'][$v])) return ['double_chance',['home/draw'=>'home_draw','home/away'=>'home_away','draw/away'=>'draw_away'][$v]];
        if($bet===8 && in_array($v,['yes','no'])) return ['btts',$v];
        if($bet===5 && preg_match('/^(over|under) (0\.5|1\.5|2\.5|3\.5)$/',$v,$m)) return ['goals_'.$m[2],$m[1]];
        return null;
    }
    public static function settle(Fixture $f,string $market,string $selection): array {
        if(in_array($f->status,['CANC','ABD','AWD','WO'])) return ['VOID',null,null,'Fixture cancelled, abandoned or awarded; no modeled regulation result.'];
        if(!in_array($f->status,['FT','AET','PEN'])) return ['PENDING',null,null,null];
        $h=data_get($f->data,'score.fulltime.home');$a=data_get($f->data,'score.fulltime.away');
        if($f->status==='FT') {$h??=$f->home_goals;$a??=$f->away_goals;}
        if(!is_numeric($h)||!is_numeric($a)) return ['PENDING',null,null,'Awaiting official regulation-time score.'];
        $h=(int)$h;$a=(int)$a;
        $win=match($market) {
            '1x2'=>match($selection){'home'=>$h>$a,'draw'=>$h===$a,'away'=>$a>$h,default=>null},
            'double_chance'=>match($selection){'home_draw'=>$h>=$a,'draw_away'=>$a>=$h,'home_away'=>$h!==$a,default=>null},
            'btts'=>match($selection){'yes'=>$h>0&&$a>0,'no'=>$h===0||$a===0,default=>null},
            default=>preg_match('/^goals_(0\.5|1\.5|2\.5|3\.5)$/',$market,$m)&&in_array($selection,['over','under']) ? ($selection==='over' ? $h+$a>(float)$m[1] : $h+$a<(float)$m[1]) : null,
        };
        return [$win===null?'PENDING':($win?'WIN':'LOSS'),$h,$a,$win===null?'Unsupported settlement market; requires additional provider data.':'Official regulation-time score'];
    }
}
