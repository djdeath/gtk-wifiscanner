#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'gtk3'
require './device'
require 'time'
require "stringio"
require 'timeout'



TIMEOUT = 61
DEVICES = Hash.new()
PERIOD = 1
def format_ss(ss)
 # return "#{100+ ss.to_i}%  (#{ss} dB)"
  return "#{100+ ss.to_i}%"
end
def insert_ssid(dev,ssid)
  if(ssid == "") then
    return
  end
  found = false
  TREESTORE.each do |model,path,iter|
    (iter[5] == dev.mac && iter[4] == ssid) and found = true
  end
  if(!found) then
    iter = TREESTORE.iter_first

    begin
      #puts "#{iter}"
    end while iter.next! && iter[0]!=dev.mac
    iter[3] = dev.nbssids.to_s
    iter[2] = format_ss(dev.ss) #dev.ss
    child = TREESTORE.append(iter)
    child[4] = ssid
    child[5] = dev.mac
  end
end

def update_treestore(dev,ssid)
  found = false
  TREESTORE.each do |model,path,iter|
    (iter[0] == dev.mac ) and found = true
  end
  if(found) then
    insert_ssid(dev,ssid)

  else
    parent = TREESTORE.append(nil)
    parent[0] = dev.mac
    parent[1] = dev.vendor
    parent[2] = format_ss(dev.ss) #dev.ss
    parent[3] = dev.nbssids.to_s

    dev.ssids.each do |ssid|
      insert_ssid(dev,ssid)
    end
  end
end
def remove_from_treestore(mac)
  to_remove = []
  TREESTORE.each do |model,path,iter|
    (iter[0] == mac ) and to_remove.push(Gtk::TreeRowReference.new(model,path))
  end

  to_remove.each do |rowref|
    (path = rowref.path) and TREESTORE.remove(TREESTORE.get_iter(path))
  end


end

def parse_line(line)
  array = line.split(';')
  time = Time.parse(array[0])
  sa = array[1]
  da= array[2]
  ss = array[3]
  ssid = array[4].chomp
  if(ss == '') then
    ss = 0
  end
  return  time, sa, da, ss, ssid
end
def update_device(sa,time,da,ss,ssid)

  dev = DEVICES[sa]
  puts dev
  if(dev==nil ) then
    dev = Device.new(time, sa, da, ss, ssid)
    DEVICES[sa]=dev
  else
    dev.update(time,ss,ssid)
  end
  puts dev
  update_treestore(dev,ssid)

  #DEVICES=DEVICES.sort{|x,y| x[3]<=>y[3]}
  #dev.display()
end

def clean_device_list()
  t_n = Time.now
  #DEVICES.delete_if {|k,v| t_n - v.get_time > TIMEOUT}
  DEVICES.each do |k,v|
    if( t_n - v.get_time > TIMEOUT) then
      remove_from_treestore(v.mac)
      DEVICES.delete(k)
    end
  end

end
def update_summary_info()
  SUMMARY_INFO.set_markup("#{DEVICES.size}")
end
def update_device_list(line)
  time, sa, da, ss, ssid = parse_line(line)
  update_device(sa,time,da,ss,ssid)
  clean_device_list()
  update_summary_info()

end


builder = Gtk::Builder.new()
builder.add_from_file('wifi-scanner.ui')

TREESTORE = builder.get_object('liststore')

def add_treeview_column(name, column_num)
        renderer = Gtk::CellRendererText.new()
        column = Gtk::TreeViewColumn.new(name, renderer, :text => column_num)
        return column
end

view = builder.get_object('treeview')

view.append_column(add_treeview_column('Identifiant', 0))
view.append_column(add_treeview_column('Constructeur', 1))
view.append_column(add_treeview_column('Force du signal', 2))
view.append_column(add_treeview_column('Nb. Réseaux', 3))
view.append_column(add_treeview_column('Réseaux', 4))

SUMMARY_INFO = builder.get_object('devices-number')
window = builder.get_object('window')
window.signal_connect("destroy") { Gtk.main_quit }
window.show_all()

GLib::Idle.add do
        begin
                status = Timeout::timeout(0.2) do
                        line = ARGF.gets
                        puts line
                        begin
                                update_device_list(line)
                        rescue
                        end
                end
        rescue Timeout::Error => e
                @error = e
                #puts "Timeout reached"
                #render :action => "error"
        end
end

Gtk.main()
