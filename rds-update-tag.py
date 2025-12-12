#!/usr/bin/env python

import boto3

# --- CONFIGURATION ---
PREFIX = 'perf'  # RDS identifier prefix
TAG_TO_UPDATE = 'Environment'
NEW_VALUE = 'PPTE'
TAG_TO_REMOVE = 'env_override'
REGION = 'ap-southeast-2'  # update your AWS region here

account_id = boto3.client('sts').get_caller_identity()['Account']

# --- CLIENTS ---
rds = boto3.client('rds', region_name=REGION)

def get_resource_tags(arn):
    return rds.list_tags_for_resource(ResourceName=arn)['TagList']

def apply_tag_changes(arn, tags):
    if tags:
        rds.add_tags_to_resource(ResourceName=arn, Tags=tags)

def remove_tag_keys(arn, tag_keys):
    if tag_keys:
        rds.remove_tags_from_resource(ResourceName=arn, TagKeys=tag_keys)

def process_rds_resource(resource_type, resource_id):
    if resource_type == 'db':
        arn = f"arn:aws:rds:{REGION}:{account_id}:db:{resource_id}"
    elif resource_type == 'cluster':
        arn = f"arn:aws:rds:{REGION}:{account_id}:cluster:{resource_id}"
    else:
        return

    tags = get_resource_tags(arn)
    updated_tags = []
    remove_keys = []

    # Update tag logic
    if any(tag['Key'] == TAG_TO_UPDATE for tag in tags):
        updated_tags.append({'Key': TAG_TO_UPDATE, 'Value': NEW_VALUE})
    else:
        # Add tag if missing
        updated_tags.append({'Key': TAG_TO_UPDATE, 'Value': NEW_VALUE})

    # Remove tag logic
    if any(tag['Key'] == TAG_TO_REMOVE for tag in tags):
        remove_keys.append(TAG_TO_REMOVE)

    print(f"\n[{resource_type.upper()}] Processing {resource_id}")
    if updated_tags:
        print(f" - Updating: {updated_tags}")
        apply_tag_changes(arn, updated_tags)
    if remove_keys:
        print(f" - Removing: {remove_keys}")
        remove_tag_keys(arn, remove_keys)

# --- MAIN ---
if __name__ == "__main__":
    # --- Process DB Instances ---
    dbs = rds.describe_db_instances()['DBInstances']
    for db in dbs:
        db_id = db['DBInstanceIdentifier']
        if db_id.startswith(PREFIX):
            process_rds_resource('db', db_id)

    # --- Process DB Clusters ---
    clusters = rds.describe_db_clusters()['DBClusters']
    for cluster in clusters:
        cluster_id = cluster['DBClusterIdentifier']
        if cluster_id.startswith(PREFIX):
            process_rds_resource('cluster', cluster_id)

