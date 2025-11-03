from setuptools import setup, find_packages

setup(
    name="rfid-streaming-ingestion",
    version="1.0.0",
    description="RFID Badge Tracking with Snowflake Snowpipe Streaming REST API",
    author="Snowflake Example",
    author_email="example@snowflake.com",
    packages=find_packages(),
    python_requires=">=3.8",
    install_requires=[
        "pydantic>=2.0.0",
        "python-dotenv>=1.0.0",
        "PyJWT>=2.8.0",
        "cryptography>=41.0.0",
        "requests>=2.31.0",
        "python-dateutil>=2.8.2",
    ],
    extras_require={
        "dev": [
            "pytest>=7.4.0",
            "pytest-cov>=4.1.0",
            "black>=23.7.0",
            "isort>=5.12.0",
            "mypy>=1.5.0",
        ],
        "load_testing": [
            "locust>=2.15.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "rfid-simulator=python.simulator.simulator:main",
        ],
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
)

