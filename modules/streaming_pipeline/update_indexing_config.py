import os
from dotenv import load_dotenv
from qdrant_client import QdrantClient
from qdrant_client.http import models
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def optimize_qdrant_collection(collection_name: str):
    """
    Optimize Qdrant collection indexing parameters for improved vector search performance.

    Args:
        collection_name (str): Name of the Qdrant collection to optimize
    """
    try:
        # Load environment variables for Qdrant credentials
        load_dotenv()

        # Initialize Qdrant client using environment variables
        client = QdrantClient(
            url=os.getenv('QDRANT_URL'),
            api_key=os.getenv('QDRANT_API_KEY')
        )

        # Update collection with optimized indexing parameters
        client.update_collection(
            collection_name=collection_name,
            optimizer_config=models.OptimizersConfigDiff(
                indexing_threshold=1000,  # Lower threshold to start indexing earlier
                max_optimization_threads=2  # Increase optimization threads
            ),
            hnsw_config=models.HnswConfigDiff(
                max_indexing_threads=4,  # Enable more indexing threads
                m=24,  # Increase graph connectivity
                ef_construct=200  # Improve index construction quality
            )
        )

        # Retrieve and log updated collection information
        collection_info = client.get_collection(collection_name)

        logger.info(f"Collection Optimization Results for '{collection_name}':")
        logger.info(f"Indexed Vectors Count: {collection_info.indexed_vectors_count}")
        logger.info(f"Total Vectors Count: {collection_info.vectors_count}")

    except Exception as e:
        logger.error(f"Error optimizing collection {collection_name}: {e}")
        raise


def main():
    """
    Main execution point for collection optimization.
    """
    try:
        optimize_qdrant_collection("alpaca_financial_news")
    except Exception as e:
        logger.error(f"Optimization failed: {e}")


if __name__ == "__main__":
    main()