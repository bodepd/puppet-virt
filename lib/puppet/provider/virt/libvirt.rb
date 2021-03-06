Puppet::Type.type(:virt).provide(:libvirt) do
	@doc = ""

	commands :virtinstall => "/usr/bin/virt-install"
	commands :grep => "/bin/grep"

	# The provider is choosed by virt_type, not by operating system
	confine :feature => :libvirt

	# 
	def dom

		Libvirt::open("qemu:///session").lookup_domain_by_name(resource[:name])

	end

	#
	def install(bootoninstall = true)

		debug "Creating a new domain %s " % [resource[:name]]

		@virt_parameter = case resource[:virt_type]
					when :xen_fullyvirt then "--hvm" #must validate kernel support
					when :xen_paravirt then "--paravirt" #Must validate kernel support
					when :kvm then "--accelerate" #Must validate hardware support
					else "Invalid value" # FIXME Raise something here?
		end

		debug "Boot on install: %s" % bootoninstall
		debug "Virtualization type: %s" % [resource[:virt_type]]

		@path="path=".concat(resource[:virt_path])

		arguments = ["--name", resource[:name], "--ram", resource[:memory], "--vcpus" , resource[:cpus] , "--disk" , @path, "--import", "--noautoconsole", "--force", @virt_parameter]

		if !bootoninstall
			arguments << "--noreboot"
		end

		virtinstall arguments 

	end

	# Changing ensure to absent
	def destroy #Changing ensure to absent

		debug "Trying to destroy domain %s" % [resource[:name]]

		begin
			dom.destroy
		rescue Libvirt::Error => e
			debug "Domain %s already Stopped" % [resource[:name]]
		end
		dom.undefine

	end


	# Creates config file if absent, and makes sure the domain is not running.
	def stop

		debug "Stopping domain %s" % [resource[:name]]

		if !exists?
			install(false)
		elsif status == "running"
#			dom.shutdown #FIXME Sometimes it doesn't shutdown
			dom.destroy
		end

	end


	# Creates config file if absent, and makes sure the domain is running.
	def start

		debug "Starting domain %s" % [resource[:name]]

		if exists? && status == "stopped"
			dom.create # Start the domain
		else
			install
		end

	end


	# Creates config file if absent, but doesn't touch the domain's state.
	# FIXME I dont like this method name
	def setinstalled

		debug "Checking if the domain %s already exists." % [resource[:name]]

		if !exists?
			install(false)
		end

	end

	# Check if the domain exists.
	def exists?

		begin
			dom
			debug "Domain %s exists? true" % [resource[:name]]
			true
		rescue Libvirt::RetrieveError => e
			debug "Domain %s exists? false" % [resource[:name]]
			false # The vm with that name doesnt exist
		end

	end


	# running | stopped | absent,				
	def status

		if exists? 
			# 1 = running, 3 = paused|suspend|freeze, 5 = stopped 
			if resource[:ensure].to_s == "installed"
				return "installed"
			elsif dom.info.state != 5
				debug "Domain %s status: running" % [resource[:name]]
				return "running"
			else
				debug "Domain %s status: stopped" % [resource[:name]]
				return "stopped"
			end
		else
			debug "Domain %s status: absent" % [resource[:name]]
			return "absent"
		end

	end

	# Is the domain autostarting?
	def isautoboot

		if !exists?
			case resource[:ensure]
				when :absent then return #do nothing
				when :running then install(true)
				else install(false)
			end
		end
	
		return dom.autostart.to_s

	end


	# Set true or false to autoboot property
	def autoboot=(value)

		debug "Trying to set autoboot %s at domain %s." % [resource[:autoboot], resource[:name]]
		begin
			if value.to_s == "false"
				dom.autostart=(false)
			else
				dom.autostart=(true)
			end
		rescue Libvirt::RetrieveError => e
			debug "Domain %s not defined" % [resource[:name]]
		end

	end

	#
	def on_poweroff=(value)
	end

	#
	def on_reboot=(value)
	end

	#
	def on_crash=(value)
	end

	# Retrieve method for "on_crash", "on_reboot" and "on_poweroff" properties
	# key must "crash", "reboot" or "poweroff"
	def getvalue(key)

		path = "/etc/libvirt/qemu/" #Debian/ubuntu path for qemu's xml files
		extension = ".xml"
		arguments =  [key, path + resource[:name] + extension]
		line = grep arguments
	
		return line.split('>')[1].split('<')[0]	

	end

end
