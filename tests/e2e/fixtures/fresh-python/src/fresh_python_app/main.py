"""Main module for the fresh Python app."""


def greet(name: str) -> str:
    """Return a greeting for the given name."""
    return f"Hello, {name}!"


def main() -> None:
    """Entry point for the application."""
    print(greet("World"))


if __name__ == "__main__":
    main()
