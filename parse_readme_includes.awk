/.. include::/ , /^[[:space:]]*:literal:/{
	if($3){
	    cmd="sed 's/^/    /' " $3;
	    print("::\n\n")
	    system(cmd);
	    next;
	} else {
	    #ignore the :literal: line
	    next;
	}
}

{print;}
