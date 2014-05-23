require 'rubygems'
require 'libowl/solver_world_model.rb'

wm = SolverWorldModel.new('localhost', 7009, 'Ben')

#Delete the object with name 'Hefei.window'
wm.deleteURI('Hefei.window')
