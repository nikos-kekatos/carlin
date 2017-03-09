r"""
This is the utils module for Carleman linearization.
It contains:
- functions to load a model
- auxiliary mathematical functions

AUTHORS:

- Marcelo Forets (2016-12) First version

"""

#************************************************************************
#       Copyright (C) 2016 Marcelo Forets <mforets@nonlinearnotes.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# any later version.
#                  http://www.gnu.org/licenses/
#************************************************************************


#===============================================
# Working numerical libraries
#===============================================

import numpy as np

import scipy
from scipy import inf

import scipy.sparse as sp
from scipy.sparse import kron, eye
import scipy.sparse.linalg
from scipy.io import loadmat, savemat

#===============================================
# Functions to load a model
#===============================================

def load_model(model_filename):
    r""" [f, n, k] = load(model_filename)
    Read an input system.

    INPUTS:

    - "model_filename" : string containin the filename

    OUTPUTS:

    - "f" : polynomial vector field. Each component belongs to the polynomial ring QQ[x1,...,xn]

    - "n" : dimension of f.

    - "k" : degree of f.

    TO-DO:

    - Accept file that is not polynomial and try to convert it to polynomial form. See automatic_recastic.ipynb notebook.

    """

    # should define n and f
    load(model_filename)

    k = max( [fi.degree() for fi in f] )

    return [f, n, k]


def get_Fj_from_model(model_filename=None, f=None, n=None, k=None):
    r""" [F, n, k] = get_Fj_from_model(...)
    Transform an input model of a polynomial vector field into standard form as a sum of Kronecker products.
    The model can be given either as an external file (model_filename), or as the tuple (f, n, k).

    INPUTS:

    - "model_filename" : string containing the filename

    OUTPUTS:

    - "F" : F is a list of sparse matrices F1, ..., Fk. These are formatted in dok (dictionary-of-keys) form.

    - "n" : dimension of the state-space of the system

    - "k" : degree of the system

    EXAMPLE:

    NOTES:

    - There was a problem with sum(1) with Sage's sum, that happens for the scalar case
       (n=1). In that case we can use: from scipy import sum
       However, now that case is handled separately.

    """

    if model_filename is not None and f is None:
        got_model_by_filename = True
    elif model_filename is not None and f is not None and n is not None and k is None:
        k = n; n = f; f = model_filename;
        got_model_by_filename = False
    else:
        raise ValueError("Either the model name or the vector field (f, n, k) should be specified.")

    if got_model_by_filename:
        [f, n, k] = load_model(model_filename)

    # create the collection of sparse matrices Fj
    F = [sp.dok_matrix((n,n^i), dtype=np.float64) for i in [1..k]]

    # read the powers appearing in each monomial
    dictionary_f = [fi.dict() for fi in f];

    if (n>1):

        for i, dictionary_f_i in enumerate(dictionary_f):
            for key in dictionary_f_i.iterkeys():
                row = i;
                j = sum(key)
                column = get_index_from_key(list(key), j, n)
                F[j-1].update({tuple([row,column]): dictionary_f_i.get(key)})

    elif (n==1): #the scalar case is treated separately

        for i, dictionary_f_i in enumerate(dictionary_f):
            for key in dictionary_f_i.iterkeys():
                row = i;
                j = key
                column = 0 # because Fj are 1x1 in the scalar case
                F[j-1].update({tuple([row,column]): dictionary_f_i.get(key)})

    return F, n, k


#===============================================
# Auxiliary mathematical functions
#===============================================

def kron_prod(x,y):
    r""" Compute the Kronecker product of two vectors x and y, and return a list. The method len should be available.
    """
    return [x[i]*y[j]  for i in range(len(x)) for j in range(len(y))]


def kron_power(x, i):
    r""" Receives a nx1 vector and computes its Kronecker power x^[i]. Assuming that i >= 1.
    """
    if (i > 2):
        return kron_prod(x, kron_power(x,i-1))
    elif (i == 2):
        return kron_prod(x,x)
    elif (i == 1):
        return x
    #elif (i==0):
#        return 1
    else:
        raise ValueError('Index i should be an integer >= 1')


def get_key_from_index(i, j, n):

    x = polygen(QQ, ['x'+str(1+k) for k in range(n)])
    x_power_j = kron_power(x, j)
    d = x_power_j[i].dict()

    return list(d.items()[0][0])


def get_index_from_key(key, j, n):
    r"""

    NOTES:

    - We assume n >= 2. Notice that if n=1, we would return always that:
    first_occurence = 0.

    TO-DO:

    - Include some bounds check?

    - Case j = sum(key) = 0. kron_power(x, 0) = 1

    """

    x = polygen(QQ, ['x'+str(1+k) for k in range(n)])
    x_power_j = kron_power(x, j)

    for i, monomial in enumerate(x_power_j):
        if ( list(monomial.dict().keys()[0]) == key):
            first_occurence = i
            break

    return first_occurence


def log_norm(A, p='inf'):
    r"""Compute the logarithmic norm of a matrix.

    INPUTS:

    * "A" - A rectangular (Sage dense) matrix of order n. The coefficients can be either real or complex.

    * "p" - (default: 'inf'). The vector norm; possible choices are 1, 2, or 'inf'.

    OUTPUT:

    * "lognorm" - The log-norm of A in the p norm.

    TO-DO:

    - Add support for a Numpy array for all values of p. (added - not tested).

    - Add support for an arbitrary p >= 1 vector norm. (how?)

    - Check assumed shape. (not sure if I want this)

    """

    # parse the input matrix
    if 'scipy.sparse' in str(type(A)):
        # cast into numpy array (or ndarray)
        A = A.toarray()
        n = A.shape[0]
    elif 'numpy.array' in str(type(A)) or 'numpy.ndarray' in str(type(A)):
        n = A.shape[0]
    else:
        # assuming sage matrix
        n = A.nrows();

    # computation, depending on the chosen norm p
    if (p == 'inf' or p == oo):
        z = max( real_part(A[i][i]) + sum( abs(A[i][j]) for j in range(n)) - abs(A[i][i]) for i in range(n))
        return z

    elif (p == 1):
        n = A.nrows();
        return max( real_part(A[j][j]) + sum( abs(A[i][j]) for i in range(n)) - abs(A[j][j]) for j in range(n))

    elif (p == 2):

        if not (A.base_ring() == RR or A.base_ring() == CC):
            return 1/2*max((A+A.H).eigenvalues())
        else:
            # Alternative, always numerical
            z = 1/2*max( np.linalg.eigvals( np.matrix(A+A.H, dtype=complex) ) )
            return real_part(z) if imag_part(z) == 0 else z

    else:
        raise ValueError('Value of p not understood or not implemented.')



def characteristics(F, n, k):
    r""" c = characteristics(F, n, k)
    where c is a dictionary containing information about the norms of the matrices in F.

    INPUTS:

    - "F" : list of matrices in a Numpy sparse format. The method toarray should be available.

    TO-DO:

    - Accept an optional parameter (params) that specifies:
        - norms chosen
    """

    import scipy as sp
    from scipy import inf
    from numpy.linalg import norm

    c = dict()

    c['norm_Fi_inf'] = [norm(F[i].toarray(), ord=inf) for i in range(k)]

    c['log_norm_F1_inf'] = log_norm(F[0], p='inf')

    if k > 1:
        if c['norm_Fi_inf'][0] != 0:
            c['beta0_const'] = c['norm_Fi_inf'][1]/c['norm_Fi_inf'][0]
        else:
            c['beta0_const'] = 'inf'

    return c


#===============================================
# Deprecated code
#===============================================


def read_polygon_list(data_file):

# data_file = '/home/mforets/Projects/synlin/biologicalmodel/x1_x2_iter_300.txt'
# biomodel_plot = read_polygon_list(data_file)
# fig = sum(p for p in biomodel_plot)
# fig.axes_labels(['$x_1$','$x_2$'])
# fig.show()

    # open file
    f = open(data_file)

    # read polygons
    v = []
    polygon_list = []
    for line in f:
        if line == '\n':
            polygon_list.append(polygon(v))
            v = []
        else:
            v.append(np.array(line.split()).astype(float))

    return polygon_list
