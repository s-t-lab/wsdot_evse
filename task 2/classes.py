# -*- coding: utf-8 -*-
"""
Created on Mon Jan 31 17:34:38 2022

@author: steff
"""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mtick

import utils as u

class EVPopulationData:
    def __init__(self, data_file, key_file):
        self.data_file = data_file
        self.key_file  = key_file
        self.key  = pd.read_csv(self.key_file)
        print(self.key.columns)
        self.data = pd.read_csv(self.data_file, names=self.key["name"])
        
        print(self.data.head(), self.data.shape)
        
        self.N = 500
        self.data = self.data.iloc[:self.N,:]
        
        #TODO: have this be read in from a config file
        self.folder = "plots/"
    
    def plot_counts_by(self, by, absrel="rel", save=False):
        fig,ax = plt.subplots()
        
        ax.bar(self.data[by].unique(), self.data[by].value_counts()/self.N)
        
        plt.xticks(rotation=45, ha="right", rotation_mode='anchor')
        if absrel=="abs":
            ax.set_ylabel("Number of EVs")
        elif absrel=="rel":
            ax.yaxis.set_major_formatter(mtick.PercentFormatter(1.0))
            ax.set_ylabel("Fraction of all EVs")
        
        if by=="ZIP Code":
            ax.set_xlim(98000, 99353)
        elif by=="County":
            ax.set_xlim(-0.6, 20.6)
        
        u.fig_ax_setup([fig,ax])
        
        if save:
            filename = self.folder + by + ".png"
            u.save_figure(fig, filename)





