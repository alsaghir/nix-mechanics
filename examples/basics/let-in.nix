let
  name = "Nix";
  answer = 40 + 2;
in
{
  greeting = "Hello, ${name}!";
  inherit answer;
}
