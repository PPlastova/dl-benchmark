import argparse
import logging as log
import sys
from pathlib import Path

from config_processor import process_config
from executors import Executor
from frameworks.framework_wrapper_registry import FrameworkWrapperRegistry
from output import OutputHandler

sys.path.append(str(Path(__file__).resolve().parents[1].joinpath('utils')))
from logger_conf import configure_logger, exception_hook  # noqa: E402


EXIT_SUCCESS = 0
EXIT_FAILURE = 1


def cli_argument_parser():
    parser = argparse.ArgumentParser()

    parser.add_argument('-c', '--config',
                        type=str,
                        dest='config_path',
                        help='Path to configuration file',
                        required=True)
    parser.add_argument('-r', '--result',
                        type=str,
                        dest='result_file',
                        help='Full name of the resulting file',
                        required=True)
    parser.add_argument('--csv_delimiter',
                        metavar='CHARACTER',
                        type=str,
                        help='Delimiter to use in the resulting file',
                        default=';')
    parser.add_argument('--executor_type',
                        type=str,
                        choices=['host_machine', 'docker_container'],
                        help='Environment ro execute test: host_machine, docker_container',
                        default='host_machine')
    parser.add_argument('-b', '--cpp_benchmark_path',
                        type=str,
                        dest='cpp_benchmark_path',
                        help='Path to pre-built C++ Benchmark App',
                        default=None,
                        required=False)

    args = parser.parse_args()

    if not Path(args.config_path).is_file():
        raise ValueError('Wrong path to configuration file!')

    return args


def inference_benchmark(executor_type, test_list, output_handler, log, cpp_benchmark_path=None):
    status = EXIT_SUCCESS

    try:
        process_executor = Executor.get_executor(executor_type, log)
    except ValueError as ex:
        log.error(ex, exc_info=True)
        return EXIT_FAILURE

    for test in test_list:
        framework_name = test.indep_parameters.inference_framework
        test_process = FrameworkWrapperRegistry()[framework_name].create_process(test, process_executor,
                                                                                 log, cpp_benchmark_path)
        test_process.execute()

        log.info('Saving test result in file\n')
        output_handler.add_row_to_table(process_executor, test, test_process)

        current_status = test_process.get_status()
        if current_status != EXIT_SUCCESS:
            status = current_status
            log.error(f'Test finished with non-zero code: {current_status}')
    return status


if __name__ == '__main__':
    configure_logger()
    sys.excepthook = exception_hook

    args = cli_argument_parser()
    test_list = process_config(args.config_path, log)

    log.info(f'Create result table with name: {args.result_file}')

    output_handler = OutputHandler(args.result_file, args.csv_delimiter)
    output_handler.create_table()

    log.info(f'Start {len(test_list)} inference tests\n')

    return_code = inference_benchmark(args.executor_type, test_list, output_handler, log, args.cpp_benchmark_path)
    log.info('Inference tests completed' if not return_code else 'Inference tests failed')
    sys.exit(return_code)
