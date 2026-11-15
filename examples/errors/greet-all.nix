let
  users = {
    ada = {
      name = "Ada";
    };
  };
  greet = user: "Hello, ${user.name}!";
  greetAll = names: builtins.concatStringsSep "\n" (map (name: greet users.${name}) names);
in
greetAll [
  "ada"
  "bob"
]
