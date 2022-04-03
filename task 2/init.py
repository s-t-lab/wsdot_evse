# -*- coding: utf-8 -*-

def run():
    import matplotlib
    
    matplotlib.pyplot.rcdefaults() #use this to change matplotlib-style-values to default
    matplotlib.pyplot.style.use(u"../evse.mplstyle")
    matplotlib.pyplot.close("all")
