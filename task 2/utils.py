# -*- coding: utf-8 -*-
"""
Library with helper functions for the EV forecasting task.
"""

import os
import requests
import numpy as np
import pandas as pd
import datetime as dt
import matplotlib
import matplotlib.pyplot as plt

t_rotation = "horizontal" #used as tick rotation
l_scilim = -5 #10^(l_scilim) used as left scilimit
r_scilim = 5 #10^(r_scilim) used as right scilimit
xl_scilim = l_scilim
xr_scilim = r_scilim
yl_scilim = l_scilim
yr_scilim = r_scilim

pad_inches = 0.05

def get_last_day_of_month(any_day):
    next_month = any_day.replace(day=28) + dt.timedelta(days=4)
    return (next_month - dt.timedelta(days=next_month.day)).date()

def get_date_from_tuple(t):
    """
    Extract the last day of the month (as a datetime.datetime object) from a given string such as "(2017, 1)" or "(2021, 10)".
    """
    y = int(t[1:5])
    m = int(t[7:8]) if len(t)==9 else int(t[7:9])
    last_day_of_month = get_last_day_of_month(dt.datetime(year=y, month=m, day=20))
    return last_day_of_month

def scrape_from_api(url, params={}, filename="scraped_data", verbose=False):
    response = requests.get(url, stream=True, params=params)
    
    if verbose:
        print("status code:", response.status_code)
        print("full url:", response.url)
        print("text:", response.text)
    
    with open(filename, "wb") as fd:
        for chunk in response.iter_content(chunk_size=1024*1024):
            fd.write(chunk)

def update_latest_file(fname_base, folder=""):
    latest_date = "2022-02-26"
    latest_date = dt.datetime.strptime(latest_date, "%Y-%m-%d")
    
    #loop through files to find the latest version of the data
    for fname in os.listdir(folder+"raw/"):
        if fname_base in fname and "as of" in fname:
            ind = fname.find("as of") + 6
            fdate = dt.datetime.strptime(fname[ind:ind+10], "%Y-%m-%d")
            if fdate > latest_date:
                latest_date = fdate
                latest_fname = fname
    
    print("latest file: '{0:s}'".format(latest_fname))

    os.popen('cp "{0:s}raw/{1:s}" "{0:s}{2:s}"'.format(folder, latest_fname, fname_base+".csv"))

fips2county = pd.read_csv("config/fips2county_tab.tsv", delimiter="\t", dtype={"CountyFIPS": str})
fips2county = fips2county.set_index("CountyFIPS")

def get_county_from_countyFIPS(countyFIPS):
    return fips2county.loc[countyFIPS, "CountyName"]

tract_to_zip = pd.read_csv("config/WA_census_tract_to_zip_code_by_res_ratio.csv", index_col="census_tract", dtype={"zip_code": int})

def create_empty_df(times, census_tracts, name_census_tracts):
    # create final dataframe and add county and ZIP code column to it
    multiindex = pd.MultiIndex.from_product([times, census_tracts], names=["time", name_census_tracts])
    df = pd.DataFrame(index=multiindex, columns=["county", "zip_code"])
    df["countyFIPS"] = df.index.get_level_values(1).values.astype("U5") #get first 5 characters of the GEOID (== stateFIPS + countyFIPS)
    df["county"] = df["countyFIPS"].apply(get_county_from_countyFIPS)
    for census_tract in census_tracts:
        if census_tract in tract_to_zip.index:
            zip_code = tract_to_zip.loc[census_tract, "zip_code"]
            df.loc[(slice(None), census_tract), "zip_code"] = zip_code
            # df.loc[(slice(None), census_tract), "county"] = search.by_zipcode(zip_code).county.replace(" County", "")
    return df

def select(L): #median of medians
    if len(L) < 10:
        L.sort()
        return L[int(len(L)/2)]
    S = []
    lIndex = 0
    while lIndex+5 < len(L)-1:
        S.append(L[lIndex:lIndex+5])
        lIndex += 5
    S.append(L[lIndex:])
    Meds = []
    for subList in S:
        # print(subList)
        Meds.append(select(subList))
    L2 = select(Meds)
    L1 = L3 = []
    for i in L:
        if i < L2:
            L1.append(i)
        if i > L2:
            L3.append(i)
    if len(L) < len(L1):
        return select(L1)
    elif len(L) > len(L1) + 1:
        return select(L3)
    else:
        return L2

def read_config_file(filename, folder="config/"):
    """
    Reads-in a configuration file using the configparser object.

    Parameters
    ----------
    filename : string
        name of the configuration file to read information from
    folder : string, optional
        path of configuration file. The default is "config/".

    Returns
    -------
    config : ConfigParser object
        ConfigParser object of concerning configuration file.
    """
    
    import configparser

    config = configparser.ConfigParser()
    config.read(folder+filename)
    return config

def plot(x, y, ey=[], ex=[], frame=[], kind="scatter", marker_option=".", 
         ls="-", lw=1, label="", color="royalblue", zorder=1, alpha=1., 
         output_folder="", filename=""):
    """
    Erstellt einen Plot (plot, scatter oder errorbar).
    
    Parameters
    ----------
    x : array-like
        x-Werte
    y : array-like
        y-Werte
    ey : array_like
        Fehler auf die y-Werte
    ex : array_like
        Fehler auf die x-Werte
    kind : string
        Die Art des plots
        Möglich sind "plot" (default), "scatter" und "errorbar".
    marker_option : string
        Definiert die Option marker bei Plottyp "plot" oder "scatter" sowie 
        die Option fmt bei Plottyp "errorbar".
    ls : string
        linestyle
    lw : float
        linewidth
    zorder : int
        Die "Ebene" der zu plottenden Daten
        
    return frame
    """
    #error arrays
    if len(ex)==1:
        ex = np.ones(len(x))*ex[0]
    elif ex==[]:
        ex = np.zeros(len(x))
    if len(ey)==1:
        ey = np.ones(len(y))*ey[0]
    
    #plotting
    fig, plot = plt.subplots(1,1) if frame == [] else frame
    if kind=="plot":
        plot.plot(x, y, color=color, marker=marker_option, ls=ls, lw=lw, label=label, zorder=zorder, alpha=alpha)
    elif kind=="scatter":
        plot.scatter(x, y, color=color, marker=marker_option, lw=lw, label=label, zorder=zorder, alpha=alpha)
    elif kind=="errorbar":
        plot.errorbar(x, y, ey, ex, color=color, fmt=marker_option, ls="", lw=lw, label=label, zorder=zorder, alpha=alpha)
    elif kind=="bar":
        plot.bar(x, y, color=color, label=label, zorder=zorder, alpha=alpha)
    
    #saving plot
    if filename!="":
        fig.savefig(output_folder+filename,bbox_inches='tight',pad_inches=pad_inches)
    
    return [fig,plot]

def fig_ax_setup(fig, suptitle=None, title=None, 
                 xlabel=None, ylabel=None, 
                 xlim=None, ylim=None, 
                 xticks=None, yticks=None, 
                 xtick_rotation=None, ytick_rotation=None, 
                 xscale="linear", yscale="linear", 
                 grid=True, legend_position="best", bbox_to_anchor=None, ncol=1, 
                 y_suptitle=1.05, axis_formatting=False, 
                 filename=None, dpi=None, transparent=0):
    
    """
    Defines the setup of a plot.
    
    Parameters
    ----------
    fig : matplotlib.Figure object (or tuple of length 2 ([fig,ax]))
        Figure object (or [fig,ax] tuple) to be set-up.
    suptitle : string
        (superordinate) title of the figure object
    title : string
        title of the axis object
    xlabel / ylabel : string
        labels/quanitities on x- and y-axis
    xlim / ylim : tuple
        axes' limits
    xticks / yticks : list
        axes' ticks
    xscale / yscale : string
        {"linear","log"}. Default is "linear".
    xtick_rotation / ytick_rotation : string or int
        Rotation of the x- and y-axis, respectively.
        Default is None.
    grid : bool
        True, if a grid is wanted. Else False.
    legend_position : None or int or string
        legend position defined by an integer or a string like "upper left". 
        Choose None for no legend.
        Default is "best".
    bbox_to_anchor : None or tuple
        Position of legend box anchor. 
        Use bbox_to_anchor=(1, 0.5) and legend_position="center left" to place 
        legend to the right of the figure.
    ncol : int
        Number of columns in the legend. 
        Default is 1.
    y_suptitle : float
        y-position of the suptitle in factors of the y-size of the figure.
        Default is 1.05.
    axis_formatting : bool
        Boolean whether to do axis_formatter commands or not.
    """
    
    #frame of figure
    if type(fig) is list or type(fig) is tuple:
        fig,ax = fig
    else: #new standard case
        ax = fig.get_axes()
    
    try:
        ax_list = list(ax)
    except:
        ax_list = [ax]
    n_ax = len(ax_list)
    
    #suptitle and title
    if suptitle is not None:
        fig.suptitle(suptitle,y=y_suptitle)
    if title is not None:
        if n_ax!=1:
            for ax,i in zip(ax_list,list(range(n_ax))):
                ax.set_title(title[i])
        else:
            ax_list[0].set_title(title)
    
    #axes labels, limits, ticks, scilimits, and scale
    if ylabel is not None:
        ax_list[0].set_ylabel(ylabel)
    for ax in ax_list:
        if xlabel is not None:
            ax.set_xlabel(xlabel)
        if xlim is not None:
            ax.set_xlim(xlim)
        if ylim is not None:
            ax.set_ylim(ylim)
        if xticks is not None:
            ax.set_xticks(xticks)
        if yticks is not None:
            ax.set_yticks(yticks)
        if xtick_rotation is not None:
            for tick in ax.xaxis.get_major_ticks():
                tick.label.set_rotation(xtick_rotation)
        if ytick_rotation is not None:
            for tick in ax.yaxis.get_major_ticks():
                tick.label.set_rotation(ytick_rotation)
        if axis_formatting:
            # axis_formatter = matplotlib.ticker.ScalarFormatter(useOffset=False)
            ax.ticklabel_format(style="sci",axis="x",scilimits=(l_scilim,r_scilim))
            ax.ticklabel_format(style="sci",axis="y",scilimits=(l_scilim,r_scilim))
            # axis_formatter = matplotlib.ticker.FuncFormatter(lambda x, p: format(int(x), ','))
            axis_formatter = matplotlib.ticker.FuncFormatter(y_fmt)
            ax.xaxis.set_major_formatter(axis_formatter)
            ax.yaxis.set_major_formatter(axis_formatter)
        if ax.get_xscale()!=xscale:
            ax.set_xscale(xscale)
        if ax.get_yscale()!=yscale:
            ax.set_yscale(yscale)
        
        #grid
        ax.grid(grid,zorder=0)
        
        #legend
        if legend_position is not None and len(ax.get_legend_handles_labels()[1])>0:
            ax.legend(loc=legend_position, bbox_to_anchor=bbox_to_anchor, ncol=ncol)
    
    #saving plot
    if filename is not None:
        save_figure(fig, filename, dpi, transparent)

def save_figure(fig, filename="figure.png", dpi=None, transparent=0):
    """
    Saves a figure that has already been set-up before completely.
    
    Parameters
    ----------
    fig : matplotlib.Figure object (or tuple of length 2 ([fig,ax]))
        Figure object (or [fig,ax] tuple) to be saved as a file.
    TODO
    """
    
    #frame of figure
    if type(fig) is list or type(fig) is tuple:
        fig,ax = fig
    else: #new standard case
        ax = fig.get_axes()
    
    #create path if it does not exist yet
    path = "/".join(filename.split("/")[:-1])
    if not os.path.exists(path):
        os.makedirs(path)
    
    if filename is not None:
        if transparent in [0,1]:
            fig.savefig(filename, dpi=dpi, bbox_inches='tight', pad_inches=pad_inches, transparent=transparent)
        else: #transparency with alpha between 0 and 1
            alpha = transparent
            fig.patch.set_facecolor('white'), fig.patch.set_alpha(alpha)
            
            try:
                ax.patch.set_facecolor('white'), ax.patch.set_alpha(alpha)
            except: #ax is in fact a list of ax objects
                for a in ax:
                    try:
                        a.patch.set_facecolor('white'), a.patch.set_alpha(alpha)
                    except: #ax is in fact a list of list of ax objects
                        for b in a:
                            b.patch.set_facecolor('white'), b.patch.set_alpha(alpha)
            
            # If we don't specify the edgecolor and facecolor for the figure when
            # saving with savefig, it will override the value we set earlier!

def n_sigma(exp_value, exp_std, true_value=0.):
    return abs(exp_value-true_value)/exp_std

