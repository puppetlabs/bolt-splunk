class splunk_qd::profile::search::ssl(
  String[1] $registration_email,
  String[1] $registration_fqdn          = $fqdn,
  Enum['internal', 'letsencrypt'] $mode = 'internal',
) inherits splunk_qd::profile::search {

  class { 'apache': default_vhost => false }

  apache::vhost { "redirect ${registration_fqdn} non-ssl":
    servername           => $registration_fqdn,
    port                 => '80',
    docroot              => "/var/www/${registration_fqdn}",
    manage_docroot       => true,
    redirect_status      => 'permanent',
    redirectmatch_regexp => '^(/(?!\.well-known/).*)',
    redirectmatch_dest   => "https://${registration_fqdn}/\$1",
  }

  if $mode == 'letsencrypt' {

    $ssl_dir = "/etc/letsencrypt/live/${registration_fqdn}"

    class { 'letsencrypt':
      email             => $registration_email,
      configure_epel    => true,
      cron_scripts_path => "${splunk::params::enterprise_homedir}/var",
    }

    letsencrypt::certonly { $registration_fqdn:
      manage_cron          => true,
      cron_hour            => [0,12],
      cron_minute          => '30',
      cron_success_command => "/bin/systemctl ${splunk::enterprise::service_name} restart",
      suppress_cron_output => true,
      domains              => [$registration_fqdn],
      plugin               => 'webroot',
      webroot_paths        => ["/var/www/${registration_fqdn}"],
      require              => Apache::Vhost["redirect ${registration_fqdn} non-ssl"],

    } -> Splunk_web <||>
  } else {

    $ssl_dir = "${splunk::params::enterprise_homedir}/etc/auth/splunkweb"
  }

  splunk_web { 'settings/enableSplunkWebSSL': value => true }
  splunk_web { 'settings/privKeyPath':        value => "${ssl_dir}/privkey.pem" }
  splunk_web { 'settings/serverCert':         value => "${ssl_dir}/cert.pem" }
}
