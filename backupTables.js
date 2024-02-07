\sql SET workload="olap";

\sql SELECT @@workload;

util.dumpSchemas(['vapor'], '/tmp/ninja/data', {showProgress: true, consistent: false, events: false, routines: false, triggers: false, threads: 16, bytesPerChunk: '64M', dataOnly: true, excludeTables: ['vapor.failed_jobs', 'vapor.oauth_access_tokens', 'vapor.oauth_refresh_tokens', 'vapor.password_resets', 'vapor.telescope_entries', 'vapor.bookingsync_events']})

\sql SELECT @@workload;