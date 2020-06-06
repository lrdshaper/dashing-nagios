SCHEDULER.every '60s' do
  require 'bundler/setup'
  require 'nagiosharder'

  environments = {
      prod: { url: 'http://my-prod-nagios/cgi-bin/nagios3/', username: 'nagios', password: 'nagios' },
      dev: { url: 'http://my-dev-nagios/cgi-bin/nagios3/', username: 'nagios', password: 'nagios' },
    }

  environments.each do |key, env|
    nag = NagiosHarder::Site.new(env[:url], env[:username], env[:password], 3, 'iso8601')
    hosts = nag.hostgroups_detail

    greens_count = 0
    reds_count = 0
    yellows_count = 0
    host_list = []
    hosts.each do |host_alert|
      if host_alert[1]["status"].eql? "DOWN"
        reds_count += 1
        stat_item = {:label => host_alert[1].host, :value => host_alert[1].status}
        host_list.push(stat_item)
      elsif host_alert[1]["status"].eql? "UNREACHABLE"
        yellows_count += 1
        stat_item = {:label => host_alert[1].host, :value => host_alert[1].status}
        host_list.push(stat_item)
      elsif host_alert[1]["status"].eql? "UP"
        greens_count += 1
      end
    end

    # nagiosharder may not alert us to a problem querying nagios.
    # If no problems found check that we fetch service status and
    # expect to find more than 0 entries.
    error = false
    if reds_count == 0 and yellows_count == 0
      if nag.hostgroups_detail.length == 0
        error = true
      end
    end

    if error
      # Send an empty payload, which the widget treats as an error
      send_event(key.to_s + '-host', { })
    else
      send_event(key.to_s + '-host', { reds: reds_count, yellows: yellows_count, greens: greens_count, red_label: "DOWN", yellow_label: "UNREACHABLE", green_label: "UP" })
      send_event(key.to_s + '-host' + '-alerts', {items: host_list})
    end

    nag = NagiosHarder::Site.new(env[:url], env[:username], env[:password], 3, 'iso8601')
    services = nag.service_status

    greens_count = 0
    reds_count = 0
    yellows_count = 0
    services_list = []
    services.each do |service_alert|
      if service_alert["status"].eql? "CRITICAL"
        reds_count += 1
        crit_item = {:label => service_alert.service + '@' + service_alert.host, :value => service_alert.status}
        services_list.push(crit_item)
      elsif service_alert["status"].eql? "WARNING"
        yellows_count += 1
        warn_item = {:label => service_alert.service + '@' + service_alert.host, :value => service_alert.status}
        services_list.push(warn_item)
      elsif service_alert["status"].eql? "OK"
        greens_count += 1
      end
    end

    # nagiosharder may not alert us to a problem querying nagios.
    # If no problems found check that we fetch service status and
    # expect to find more than 0 entries.
    error = false
    if reds_count == 0 and yellows_count == 0
      if nag.service_status.length == 0
        error = true
      end
    end

    if error
      # Send an empty payload, which the widget treats as an error
      send_event(key.to_s + '-service', { })
    else
      send_event(key.to_s + '-service', { reds: reds_count, yellows: yellows_count, greens: greens_count, red_label: "CRITICAL", yellow_label: "WARNING", green_label: "OK" })
      send_event(key.to_s + '-service' + '-alerts', {items: services_list})
    end
  end
end

