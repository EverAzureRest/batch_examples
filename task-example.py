
from datetime import datetime, timedelta
import azure.batch.batch_auth as batchauth
import azure.batch._batch_service_client as batch 
import uuid
import datetime
import time

# Batch account credentials
BATCH_ACCOUNT_NAME = ''
BATCH_ACCOUNT_URL = ''
BATCH_ACCOUNT_KEY = ''

# Create a Batch service client. We'll now be interacting with the Batch
# service in addition to Storage.
credentials = batchauth.SharedKeyCredentials(BATCH_ACCOUNT_NAME,
                                             BATCH_ACCOUNT_KEY)

batch_client = batch.BatchServiceClient(
    credentials,
    batch_url=BATCH_ACCOUNT_URL)

pool = batch_client.pool.get(
    pool_id='testPool'
)

##ToDO: Create nodes prior to run. 
poolResizeParam = batch.models.PoolResizeParameter(
    target_dedicated_nodes=1
)

batch_client.pool.resize(
    pool_id=pool.id,
    pool_resize_parameter=poolResizeParam
)

job = batch.models.JobAddParameter(
    id=str(uuid.uuid1()),
    display_name='myBatchJob',
    pool_info=batch.models.PoolInformation(
        pool_id=pool.id
    ),
    uses_task_dependencies = 'true'
)

job1 = batch_client.job.add(job)

task1 = batch.models.TaskAddParameter(
    id='task1',
    command_line='cmd /c echo "Hello From Batch" >task.txt'

)

dependentTasks = list()
dependentTasks.append(task1.id)

task2 = batch.models.TaskAddParameter(
    id='task2',
    command_line = 'cmd /c echo "this is task2 - should execute after task 1" >task2.txt',
    depends_on = batch.models.TaskDependencies(task_ids=dependentTasks)
)

tasks = list()
tasks.append(task1)
tasks.append(task2)

batch_client.task.add_collection(
    job_id=job.id,
    value=tasks
)

# Perform action with the batch_client
jobs = batch_client.job.list()

for job in jobs:
    print(job.id)

##Todo, watch tasks for completion and resize pool to zero

job_timeout = timedelta(minutes=30)

timeout_expiration = datetime.datetime.now() + job_timeout

while datetime.datetime.now() < timeout_expiration:
    tasks = batch_client.task.list(job.id)
    incomplete_tasks = [task for task in tasks if
                        task.state != batch.models.TaskState.completed]

    if not incomplete_tasks:
        time.sleep(600)
        newpoolResizeParam = batch.models.PoolResizeParameter(
            target_dedicated_nodes=0
        )
        batch_client.pool.resize(
            pool_id=pool.id,
            pool_resize_parameter=newpoolResizeParam
        )
    else:
        time.sleep(1)