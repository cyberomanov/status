from sys import stderr

from loguru import logger

from config import OUTPUT_LOG_PATH


class Logger:
    def __init__(self):
        logger.remove()
        logger.add(stderr, format="<bold><blue>{time:HH:mm:ss}</blue>"
                                  " | <level>{level}</level>"
                                  " | <level>{message}</level></bold>")
        logger.add(OUTPUT_LOG_PATH, rotation="500 MB")

    @staticmethod
    def add_info_record(message: str):
        logger.info(message)

    @staticmethod
    def add_warn_record(message: str):
        logger.warning(message)

    @staticmethod
    def add_exception_record(exception: Exception):
        logger.exception(exception)

    @staticmethod
    def add_error_record(message: str):
        logger.error(message)
