use JSON qw( decode_json );

my $password = "my secure password";

sub matrix_deactivate_account
{
   my ( $user, $password ) = @_;

   do_request_json_for( $user,
      method  => "POST",
      uri     => "/r0/account/deactivate",
      content => {
         auth => {
            type     => "m.login.password",
            user     => $user->user_id,
            password => $password,
         },
      },
   );
}

test "Can deactivate account",
   requires => [ local_user_fixture( password => $password ) ],

   check => sub {
      my ( $user ) = @_;

      matrix_deactivate_account( $user, $password );
   };

test "Can't deactivate account with wrong password",
   requires => [ local_user_fixture( password => $password ) ],

   check => sub {
      my ( $user ) = @_;

      matrix_deactivate_account( $user, "wrong password" )
      ->main::expect_http_401->then( sub {
         my ( $resp ) = @_;

         my $body = decode_json $resp->content;

         assert_json_keys( $body, qw( error errcode params completed flows ));

         my $errcode = $body->{errcode};

         $errcode eq "M_FORBIDDEN" or
            die "Expected errcode to be M_FORBIDDEN but was $errcode";

         Future->done(1);
      });
   };

test "After deactivating account, can't log in with password",
   requires => [ local_user_fixture( password => $password ) ],

   check => sub {
      my ( $user ) = @_;

      matrix_deactivate_account( $user, $password )
      ->then( sub {
         do_request_json_for( $user,
            method  => "POST",
            uri     => "/r0/login",
            content => {
               type     => "m.login.password",
               user     => $user->user_id,
               password => $password,
            }
         # We don't mandate the exact failure code here
         # (that should be done in the login test if
         # anywhere), any 4xx code is fine as far as
         # this test is concerned.
         )->main::expect_http_4xx;
      });
   };
