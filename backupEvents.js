\sql SET workload="olap";

\sql SELECT @@workload;

util.dumpTables('vapor', ['bookingsync_events'], '/tmp/${INPUT_IDENTIFIER}/data', {'where' : {'vapor.bookingsync_events': 'team_id=1', 'vapor.bookingsync_events': 'created_at > CURRENT_DATE - INTERVAL 1 MONTH'}})

\sql SELECT @@workload;