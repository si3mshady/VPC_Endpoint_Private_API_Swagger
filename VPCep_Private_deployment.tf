terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.5"
    }
  }
}


resource "aws_vpc_endpoint" "vpcep" {
  vpc_id            = "vpc-0a5d037ca47cebc9b"
  service_name      = "com.amazonaws.us-east-1.execute-api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = ["subnet-03653dd0663e86455"]
  security_group_ids = [ "sg-02b02e305ab6095e1" ]

  private_dns_enabled = true
}

resource "aws_api_gateway_rest_api" "mock_api" {
  
  body = jsonencode({
    openapi = "3.0.1"   
    paths = {
      "/sunday" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"         
            type                 = "MOCK"
          
          }
        }
      }
    }
  })

  name = "si3mshady_mock_api"
  endpoint_configuration {
    types = ["PRIVATE"]
    vpc_endpoint_ids = [aws_vpc_endpoint.vpcep.id]
  }
}


resource "aws_api_gateway_stage" "mock_stage" {
  deployment_id = aws_api_gateway_deployment.mock_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.mock_api.id
  stage_name    = "si3mshady"
}



resource "aws_api_gateway_rest_api_policy" "mock" {
  rest_api_id = aws_api_gateway_rest_api.mock_api.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "*",
      "Resource": "*"      
    }
  ]
}
EOF
}


resource "aws_api_gateway_resource" "mock" {
  parent_id   = aws_api_gateway_rest_api.mock_api.root_resource_id
  path_part   = "mock_resource"
  rest_api_id = aws_api_gateway_rest_api.mock_api.id
}

resource "aws_api_gateway_method" "mock_method" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.mock.id
  rest_api_id   = aws_api_gateway_rest_api.mock_api.id
}


resource "aws_api_gateway_integration" "mock_integration" {
  http_method = aws_api_gateway_method.mock_method.http_method
  resource_id = aws_api_gateway_resource.mock.id
  rest_api_id = aws_api_gateway_rest_api.mock_api.id
  type        = "MOCK"
  request_templates = {
    "application/json": "{\"statusCode\": 200}"
  }


}

resource "aws_api_gateway_method_response" "mock_response_200" {
  rest_api_id =  aws_api_gateway_rest_api.mock_api.id
  resource_id = aws_api_gateway_resource.mock.id
  http_method = aws_api_gateway_method.mock_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_deployment" "mock_deployment" {
  rest_api_id = aws_api_gateway_rest_api.mock_api.id

  lifecycle {
    create_before_destroy = true
  }

   depends_on = ["aws_api_gateway_method.mock_method", "aws_api_gateway_integration.mock_integration"]
}



resource "aws_api_gateway_integration_response" "mock_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.mock_api.id
  resource_id = aws_api_gateway_resource.mock.id
  http_method = aws_api_gateway_method.mock_method.http_method
  status_code = aws_api_gateway_method_response.mock_response_200.status_code

}


# https://forums.aws.amazon.com/thread.jspa?threadID=255953
# curl -v  https://vpce-0e6434e392a1b5383-bel901g5.execute-api.us-east-1.vpce.amazonaws.com/si3mshady/sunday -H'x-apigw-api-id:2m02nk0mkg'
# https://2m02nk0mkg.execute-api.us-east-1.amazonaws.com/si3mshady/sunday
#curl -v  https://vpce-06dd0b08f09790e00-yzt77tg5.execute-api.us-east-1.vpce.amazonaws.com/si3mshady/saturday -H'x-apigw-api-id:9nezaomcgc'
#curl -v https://{public-dns-hostname}.execute-api.{region}.vpce.amazonaws.com/test -H'x-apigw-api-id:{api-id}'
# https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-private-api-test-invoke-url.html
