import json, numpy as np, pandas as pd, pywbgt
from pywbgt.calc import *  # noqa
from metpy.units import units
from metpy.calc import dewpoint_from_relative_humidity
d=json.load(open('era5.json'))['hourly']
df=pd.DataFrame(d); df['time']=pd.to_datetime(df['time'])
df=df.dropna().reset_index(drop=True)
print('rows',len(df), df.time.min(), df.time.max())
T=df.temperature_2m.values*units.degC; RH=df.relative_humidity_2m.values*units.percent
Td=dewpoint_from_relative_humidity(T,RH)
dt=pd.DatetimeIndex(df.time)
common=dict(datetime=dt,lat=np.array([9.88]),lon=np.array([-85.53]),pres=df.surface_pressure.values*units.hPa,
            temp_air=T,temp_dew=Td,gmt=np.full(len(df),-6.0),avg=np.full(len(df),60.0))
sun=pywbgt.liljegrenWBGT(solar=df.shortwave_radiation.values*units('W/m**2'),speed=df.wind_speed_10m.values*units('m/s'),zspeed=10*units.m,**common)
w2=sun['speed'].magnitude
shade=pywbgt.liljegrenWBGT(solar=np.zeros(len(df))*units('W/m**2'),speed=w2*units('m/s'),zspeed=2*units.m,**common)
df['wind2m']=w2; df['wbgt_sun']=sun['Twbg'].magnitude; df['wbgt_shade']=shade['Twbg'].magnitude
df['tg_sun']=sun['Tg'].magnitude; df['tnwb_sun']=sun['Tnwb'].magnitude
print('nan sun/shade',df.wbgt_sun.isna().sum(),df.wbgt_shade.isna().sum())
# NWS heat index (WPC Rothfusz with adjustments)
def hi(Tc,rh):
    T=Tc*9/5+32
    s=0.5*(T+61+(T-68)*1.2+rh*0.094)
    avg=(s+T)/2
    r=(-42.379+2.04901523*T+10.14333127*rh-.22475541*T*rh-.00683783*T*T-.05481717*rh*rh
       +.00122874*T*T*rh+.00085282*T*rh*rh-.00000199*T*T*rh*rh)
    adj1=np.where((rh<13)&(T>80)&(T<112),((13-rh)/4)*np.sqrt(np.clip((17-np.abs(T-95))/17,0,None)),0)
    adj2=np.where((rh>85)&(T>80)&(T<87),((rh-85)/10)*((87-T)/5),0)
    r=r-adj1+adj2
    return np.where(avg>=80,r,s)
df['hi_f']=hi(df.temperature_2m.values,df.relative_humidity_2m.values)
# BoM simple approx for comparison: 0.567Ta+0.393e+3.94, e in hPa
e=df.relative_humidity_2m/100*6.105*np.exp(17.27*df.temperature_2m/(237.7+df.temperature_2m))
df['wbgt_bom']=0.567*df.temperature_2m+0.393*e+3.94
df['md']=df.time.dt.strftime('%m-%d'); df['hour']=df.time.dt.hour; df['year']=df.time.dt.year
df=df[df.md!='02-29']
df.to_parquet('hourly_all.parquet')
# window
days=pd.date_range('2026-12-05','2027-06-01',freq='D'); assert len(days)==179
mds=[x.strftime('%m-%d') for x in days]
idx={m:i+1 for i,m in enumerate(mds)}
w=df[df.md.isin(mds)].copy(); w['day_index']=w.md.map(idx)
g=w.groupby(['day_index','md','hour'])
cols={'temperature_2m':'temp_c','relative_humidity_2m':'rh_pct','wind_speed_10m':'wind_ms','wind2m':'wind2m_ms','shortwave_radiation':'swr_wm2','direct_radiation':'direct_wm2','diffuse_radiation':'diffuse_wm2','surface_pressure':'pressure_hpa','wbgt_shade':'wbgt_shade_c','wbgt_sun':'wbgt_sun_c','hi_f':'heat_index_shade_f','wbgt_bom':'wbgt_bom_approx_c'}
out=g[list(cols)].mean().rename(columns=cols).reset_index().rename(columns={'md':'month_day'})
out['n_years']=g.size().values
# p90 pooled +-3 days (wrap within the window only by day_index)
p90={}
for k,c in [('wbgt_shade','wbgt_shade_p90_c'),('wbgt_sun','wbgt_sun_p90_c'),('hi_f','heat_index_shade_p90_f')]:
    vals=[]
    for di in range(1,180):
        sub=w[(w.day_index>=di-3)&(w.day_index<=di+3)]
        vals.append(sub.groupby('hour')[k].quantile(0.9).rename(di))
    p=pd.concat(vals,axis=1).T.stack().rename(c).reset_index().rename(columns={'level_0':'day_index'})
    out=out.merge(p,on=['day_index','hour'])
def zone(x):
    x=np.round(x,1)
    return np.select([x<25.7,x<27.9,x<30.1,x<32.3],['Warm','Hot','Very hot','Peak heat'],'Extreme')
def hizone(f):
    f=np.round(f,0)
    return np.select([f<80,f<90,f<103,f<125],['Below Caution','Caution','Extreme Caution','Danger'],'Extreme Danger')
out['zone_shade']=zone(out.wbgt_shade_c); out['zone_sun']=zone(out.wbgt_sun_c)
out['zone_shade_p90']=zone(out.wbgt_shade_p90_c); out['zone_sun_p90']=zone(out.wbgt_sun_p90_c)
out['hi_category_shade']=hizone(out.heat_index_shade_f)
num=out.select_dtypes('number').columns.difference(['day_index','hour','n_years'])
out[num]=out[num].astype("float64").round(1)
order=['day_index','month_day','hour','temp_c','rh_pct','wind_ms','wind2m_ms','swr_wm2','direct_wm2','diffuse_wm2','pressure_hpa','wbgt_shade_c','wbgt_sun_c','zone_shade','zone_sun','wbgt_shade_p90_c','wbgt_sun_p90_c','zone_shade_p90','zone_sun_p90','heat_index_shade_f','hi_category_shade','heat_index_shade_p90_f','wbgt_bom_approx_c','n_years']
out=out[order].sort_values(['day_index','hour'])
out.to_csv('../partner-hourly.csv',index=False)
w.to_parquet('window_hourly.parquet')
print(out.shape); print(out[out.day_index==120].to_string())
