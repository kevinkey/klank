require 'yaml'
require 'ruby-graphviz'

module KlankMapGen
	class Map
		
		def initialize(file, dark = false, images = false)
            @yml = file
            @map = YAML.load(File.read(@yml))
			@colors = dark ? 
						{ 'bg_color'=>'black', 'border_color'=>'white', 'room_font_color'=>'black', 'path_font_color'=>'black' } :
						{ 'bg_color'=>'white', 'border_color'=>'black', 'room_font_color'=>'black', 'path_font_color'=>'black' }
			@use_images = images

            # make sure every room has a hash with "secrets", etc. defined (default 0)
            @map['rooms'].each_key do |room_num|
                @map['rooms'][room_num] = {
                    'major-secrets' => 0,
                    'minor-secrets' => 0,
                    'monkey-idols' => 0,
                    'heal' => 0,
                    'artifact' => 0,
                    'crystal-cave' => false,
                    'store' => false
                }.merge(@map['rooms'][room_num] || {})
            end

            # make sure every path has a hash with "move", "attack", etc. defined (default 1 and 0)
            @map['paths'].each_key do |key|
                @map['paths'][key] = {
                    'move' => 1,
                    'attack' => 0,
                    'locked' => false
                }.merge(@map['paths'][key] || {})
            end
        end

        def generate_map_path_node(g, key)
			if @map['paths'][key] # valid key
                if @map['paths'][key]['node'].nil? # not already generated
                    labels = []
                    labels << 'M'+@map['paths'][key]['move'].to_s if (@map['paths'][key]['move'] > 1)
                    labels << 'A'+@map['paths'][key]['attack'].to_s if (@map['paths'][key]['attack'] > 0)
					labels << 'L' if @map['paths'][key]['locked']
					if labels.count > 0
						image = './images/' + labels.sort.join('') + '.png'
						if (@use_images && File.exist?(image))
							style = 'none'
							labels = []
							width = '0.1'
						else
							style = 'filled'
							image = 'none'
							width = '0.5'
						end
						@map['paths'][key]['node'] = g.add_nodes( key,
                                                                'label' => labels.join("\n"),
																'fontcolor' => @colors['path_font_color'],
																'fontname' => 'Helvetica-Bold',
																'fontsize' => 8.0,
																'width' => width,
																'image' => image,
																'imagescale' => true,
																'shape' => 'circle',
																'style' => style,
																'color' => @colors['border_color'],
																'fillcolor' => 'white' )
					else
                        # insert a dummy path node to give graphviz a little more flexibility
                        @map['paths'][key]['node'] = g.add_nodes( key,
                                                                'label' => '',
																'fontcolor' => @colors['path_font_color'],
																'fontname' => 'Helvetica-Bold',
																'fontsize' => 8.0,
                                                                'width' => '0.1',
                                                                'shape' => 'circle',
																'style' => 'filled',
																'color' => @colors['border_color'],
																'fillcolor' => 'white' )
                    end
                end
                @map['paths'][key]['node']
            end
        end

        def generate_map_graph
            #####################
            # Create a new graph
			#####################
			# tbd ksh !!! not sure it makes any difference using graph vs digraph (look into this more)
            g = GraphViz.new( :G, :type => :graph, #:digraph, 
                              :use => 'dot', 
                              :resolution => 160,    # make output image a little clearer
							  :overlap => 'false',   # avoid overlapping nodes
							  :bgcolor => @colors['bg_color'] )  

            #####################
            # Now generate all the nodes for the rooms, and any path labels
            #####################
            # simple heuristic to determine how many nodes to put on each rank
            # this helps with rank ordering
            room_start = 1
            above_count = @map['depths'] - 2
			above_step = (above_count % 5 == 0) ? 5 :
						 (above_count % 4 == 0) ? 4 : 5 
            below_count = @map['rooms'].count - @map['depths'] + 1
            below_step = (below_count % 6 == 0) ? 6 : 
                         (below_count % 5 == 0) ? 5 : 
                         (below_count % 4 == 0) ? 4 : (above_step + 1)
            while (room_start <= @map['rooms'].count) do
                step = (room_start >= @map['depths']) ? below_step : above_step 
                room_end = [room_start + step - 1, @map['rooms'].count].min
                if (room_start == 1)
                    room_end = 1 # start node on it's own rank
                elsif (room_start < @map['depths']) && (room_end >= @map['depths'])
                    room_end = @map['depths'] - 1  # start a new rank for depths
				end
				c = g.add_graph('rank' => 'same')
				for room_num in (room_start .. room_end) do
					# determine shape and color for room
					shape, color, width, height = 'box', 'lightgrey', 1.22, 0.96
					image = (room_num < @map['depths']) ? './images/room.png' : './images/room-depths.png'
					room_font_color = @use_images ? 'white' : @colors['room_font_color']
					if @map['rooms'][room_num]['crystal-cave']
						shape, color, width, height = 'circle', 'lightblue', 1.4, 1.4
						image = './images/crystal-cave.png'
					elsif (@map['rooms'][room_num]['monkey-idols'] > 0)
						shape, color, width, height = 'box', 'khaki', 1.13, 2.46
						image = './images/monkey-idols.png'
					elsif @map['rooms'][room_num]['store']
						shape, color, width, height = 'box', 'gold', 1.19, 1.39
						image = './images/store.png'
					end
					if (@map['rooms'][room_num]['heal'] > 0)
						color = 'red'  # always make heal rooms red
						room_font_color = 'red' if (@use_images)
					end
					labels = [ "ROOM: #{room_num}" ]
					@map['rooms'][room_num].each do |key, value|
						next if (@use_images) && (key == 'minor-secrets') && (value == 2)
						next if (@use_images) && (key == 'major-secrets') && (value == 1)
						next if (@use_images) && (key == 'heal') && (value == 1)
						next if (@use_images) && ((key == 'store') || (key == 'monkey-idols') || (key == 'crystal-cave') || (key == 'crystal-cave'))
						labels << "#{key}: #{value}" if (value == true) || ((value != false) && (value > 0)) 
					end
					label = labels.join("\n")
					# is use_images, use 'html-like' node labels to get an image on image
					# for heals, major-secrets, and minor-secrets
					if (@use_images && (@map['rooms'][room_num]['heal'] > 0))
						label = labels.join("<br />")
						label = "<<table border='0' cellborder='0' cellpadding='0' cellspacing='0'>" + 
								 "<tr><td width='40' height='37'><img src='./images/heal.png' /></td></tr>"+
								 "<tr><td>#{label}</td></tr></table>>"
					elsif (@use_images && (@map['rooms'][room_num]['major-secrets'] > 0))
						label = labels.join("<br />")
						label = "<<table border='0' cellborder='0' cellpadding='0' cellspacing='0'>" + 
									"<tr><td width='50' height='50'><img src='./images/major-secrets.png' /></td></tr>"+
									"<tr><td>#{label}</td></tr></table>>"
					elsif (@use_images && (@map['rooms'][room_num]['minor-secrets'] > 0))
						label = labels.join("<br />")
						label = "<<table border='0' cellborder='0' cellpadding='0' cellspacing='0'>" + 
									"<tr><td width='40' height='40'><img src='./images/minor-secrets.png' /></td></tr>"+
									"<tr><td>#{label}</td></tr></table>>"
					end
					@map['rooms'][room_num]['node'] = c.add_nodes( "#{room_num}",
																	'label' => label, 
																	'fontcolor' => room_font_color,
																	'fontname' => 'Helvetica-Bold',
																	'fontsize' => 8.0,
																	'width' => width,
																	'height' => height,
																	'penwidth' => 3.0,
																	'image' => (@use_images) ? image : 'none',
																	'imagescale' => true,
																	'shape' => shape,
																	'style' => 'filled',
																	'color' => (room_num < @map['depths']) ? 'green' : 'brown',
																	'fillcolor' => color )
					if (room_num+1) <= room_end
						# generate path nodes for any LR adjacent nodes on this rank
						# this helps with rank ordering
						generate_map_path_node(c, "#{room_num}-#{room_num+1}")
						generate_map_path_node(c, "#{room_num+1}-#{room_num}")
					end
				end
                # generate path nodes for any paths from this rank to lower ranks
                # this helps with rank ordering
				c = g.add_graph('rank' => 'same')
				for n1 in (room_start .. room_end) do
					for n2 in ((n1+1) .. @map['rooms'].count) do
						generate_map_path_node(c, "#{n1}-#{n2}")
						generate_map_path_node(c, "#{n2}-#{n1}")
					end
				end
                # go to next set of nodes for next rank
                room_start = room_end + 1
            end

            #####################
            # Now generate edges for all the paths (two edges because path nodes)
            #####################
            # sort keys by lowest node first, so a 7-3 one-way path is generated with other 3's
            # this helps with rank ordering
            keys = @map['paths'].keys.sort do |l, r| 
                l =~ /^(\d+)-(\d+)$/
                l1, l2 = $1.to_i, $2.to_i
                if l2<l1 then l1, l2 = l2, l1 end # swap
                r =~ /^(\d+)-(\d+)$/
                r1, r2 = $1.to_i, $2.to_i
                if r2<r1 then r1, r2 = r2, r1 end # swap
                l1==r1 ? l2<=>r2 : l1<=>r1
            end
            keys.each do |key|
				path_node = generate_map_path_node(g, key) # get or create path node
				key =~ /^(\d+)-(\d+)$/
                n1, n2 = $1.to_i, $2.to_i
				if n2<n1 then back, n1, n2 = true, n2, n1 end # swap
                # Create edges between the nodes (n1=path_node=n2)
                g.add_edges( @map['rooms'][n1]['node'], 
                                path_node, 
								'penwidth' => 3.0,
								'dir' => (@map['paths'][key]['one-way'] && back) ? 'back' : 'none',
								'color' => @colors['border_color'] )
                g.add_edges( path_node, 
                                @map['rooms'][n2]['node'], 
                                'penwidth' => 3.0,
                                'dir' => (@map['paths'][key]['one-way'] && !back) ? 'forward' : 'none',
								'color' => @colors['border_color'] )
            end

            #####################
            # Generate output image
            #####################
            base = File.basename(@yml, '.*')
            g.output( :png => "#{base}.png" )
            # this generates a text file containing the .dot notation
            # it can be used at the following site to generate an
            # 'ascii art' version of the map.
            # https://dot-to-ascii.ggerganov.com/
            g.output( :dot => "#{base}.dot" )
        end
    end
end
